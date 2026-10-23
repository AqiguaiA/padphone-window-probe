#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

int main(void) {
    @autoreleasepool {
        NSArray<NSString *> *names = @[@"UIWindowScene", @"UIWindowSceneGeometryPreferencesIOS",
            @"UIWindowSceneGeometryPreferences", @"UISceneSizeRestrictions",
            @"FBSSceneClientSettings", @"FBSMutableSceneClientSettings",
            @"UIApplicationSceneClientSettings", @"UIMutableApplicationSceneClientSettings"];
        NSArray<NSString *> *terms = @[@"size", @"frame", @"geometry", @"restric", @"resiz", @"clientsetting"];
        for (NSString *name in names) {
            Class cls = NSClassFromString(name);
            printf("CLASS %s %s\n", name.UTF8String, cls ? "present" : "absent");
            if (!cls) continue;
            unsigned int count = 0;
            Method *methods = class_copyMethodList(cls, &count);
            for (unsigned int i = 0; i < count; i++) {
                NSString *selector = NSStringFromSelector(method_getName(methods[i]));
                for (NSString *term in terms) {
                    if ([selector.lowercaseString containsString:term]) {
                        printf("METHOD %s %s\n", selector.UTF8String, method_getTypeEncoding(methods[i]));
                        break;
                    }
                }
            }
            free(methods);
            objc_property_t *properties = class_copyPropertyList(cls, &count);
            for (unsigned int i = 0; i < count; i++) {
                NSString *property = @(property_getName(properties[i]));
                for (NSString *term in terms) {
                    if ([property.lowercaseString containsString:term]) {
                        printf("PROPERTY %s %s\n", property.UTF8String, property_getAttributes(properties[i]));
                        break;
                    }
                }
            }
            free(properties);
        }
    }
    return 0;
}
