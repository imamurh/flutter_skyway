#import "FlutterSkywayPlugin.h"
#import <flutter_skyway/flutter_skyway-Swift.h>

@implementation FlutterSkywayPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterSkywayPlugin registerWithRegistrar:registrar];
}
@end
