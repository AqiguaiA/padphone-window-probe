"""Probe actual iPadOS window restrictions without building a PadPhone IPA."""
from pathlib import Path
import json
import os
import plistlib
import shutil
import subprocess


def run(*args):
    return subprocess.check_output(args, text=True, timeout=90).strip()


def main():
    output = Path('build/window-probe').resolve()
    output.mkdir(parents=True, exist_ok=True)
    sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
    print(run('xcodebuild', '-version'), flush=True)
    print(run('xcrun', 'simctl', 'list', 'runtimes'), flush=True)
    for header in ['UIWindowScene.h', 'UIWindowSceneGeometryPreferencesIOS.h', 'UISceneSizeRestrictions.h']:
        path = Path(sdk) / 'System/Library/Frameworks/UIKit.framework/Headers' / header
        print(f'{header}:\n{path.read_text()}', flush=True)
    listing = json.loads(run('xcrun', 'simctl', 'list', '-j'))
    runtime = next(r for r in listing['runtimes'] if r.get('isAvailable') and r['name'].startswith('iOS 27.0'))
    devices = [d for d in listing['devicetypes'] if 'iPad Pro' in d['name'] and '13-inch' in d['name']]
    assert devices, 'No matching iPad Pro simulator device type'
    device_type = next((d for d in devices if 'M4' in d['name']), devices[0])
    device = run('xcrun', 'simctl', 'create', 'PadPhone Window Probe', device_type['identifier'], runtime['identifier'])
    run('xcrun', 'simctl', 'boot', device)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', device, '-b'], check=True, timeout=180)
    bundle_id = 'local.padphone.windowprobe'
    subprocess.run(['xcodegen', 'generate', '--spec', 'tests/WindowProbe/project.yml'], check=True)
    prebuilt = os.environ.get('PROBE_PREBUILT_APP')
    completed = subprocess.run(['xcodebuild', '-project', 'tests/WindowProbe/WindowProbe.xcodeproj',
                               '-scheme', 'WindowProbe', '-sdk', 'iphonesimulator',
                               '-destination', 'id=' + device, '-derivedDataPath', str(output / 'DerivedData'),
                               '-resultBundlePath', str(output / ('CompileResults.xcresult' if prebuilt else 'TestResults.xcresult')),
                               'PROBE_DEVICE_FAMILY=' + os.environ.get('PROBE_DEVICE_FAMILY', '2'),
                               'CODE_SIGNING_ALLOWED=NO', 'build-for-testing' if prebuilt else 'test'], timeout=720)
    if prebuilt:
        assert completed.returncode == 0, 'Could not build the simulator test driver'
        products = output / 'DerivedData/Build/Products'
        installed = products / 'Debug-iphonesimulator/WindowProbe.app'
        shutil.copytree(prebuilt, installed, dirs_exist_ok=True)
        print(run('xcrun', 'vtool', '-show-build', str(installed / 'WindowProbe')), flush=True)
        test_runs = list(products.glob('*.xctestrun'))
        assert len(test_runs) == 1, 'Expected exactly one simulator test plan'
        completed = subprocess.run(['xcodebuild', 'test-without-building', '-xctestrun', str(test_runs[0]),
                                   '-destination', 'id=' + device, '-resultBundlePath', str(output / 'TestResults.xcresult')],
                                   timeout=300)
    data = Path(run('xcrun', 'simctl', 'get_app_container', device, bundle_id, 'data'))
    app = Path(run('xcrun', 'simctl', 'get_app_container', device, bundle_id, 'app'))
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    print('Installed device family:', info['UIDeviceFamily'], 'SDK:', info['DTSDKName'],
          'UIRequiresFullScreen:', info.get('UIRequiresFullScreen'), flush=True)
    expected_family = [int(value) for value in os.environ.get('PROBE_DEVICE_FAMILY', '2').split(',')]
    assert info['UIDeviceFamily'] == expected_family, 'Wrong probe device family installed'
    if prebuilt:
        assert info['DTSDKName'] == 'iphonesimulator26.5', 'Did not execute the release-SDK probe'
    report = data / 'Documents/window-report.json'
    run('xcrun', 'simctl', 'io', device, 'screenshot', str(output / 'window.png'))
    assert report.exists(), f'Window probe did not produce a report; UI test exit={completed.returncode}'
    shutil.copy2(report, output / report.name)
    results = json.loads(report.read_text())
    print(json.dumps(results, indent=2), flush=True)
    products = output / 'DerivedData/Build/Products/Debug-iphonesimulator'
    runner_infos = list(products.glob('*-Runner.app/Info.plist'))
    assert len(runner_infos) == 1, 'Missing test driver metadata'
    runner_info = plistlib.loads(runner_infos[0].read_bytes())
    assert 2 in runner_info['UIDeviceFamily'], 'Test driver must support native iPad windows'
    runner_data = Path(run('xcrun', 'simctl', 'get_app_container', device, runner_info['CFBundleIdentifier'], 'data'))
    external_report = runner_data / 'Documents/window-external-report.json'
    assert external_report.exists(), 'Missing measurements of the outside window'
    shutil.copy2(external_report, output / external_report.name)
    external = json.loads(external_report.read_text())
    print(json.dumps(external, indent=2), flush=True)
    assert completed.returncode == 0, 'Simulator UI test failed'
    assert len(results) == len(external) == 3, 'Missing portrait/landscape/portrait result'
    assert all(r['edgeGap'] <= 1 for r in results), 'Picture has internal black bars'
    if 2 in info['UIDeviceFamily']:
        assert all(r['passed'] for r in results), 'iPadOS did not apply fixed window size'
    assert all(r['passed'] for r in external), 'Outside window did not follow or retain the phone size'


if __name__ == '__main__':
    main()
