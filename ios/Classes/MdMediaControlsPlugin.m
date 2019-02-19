#import "MdMediaControlsPlugin.h"
#import <md_media_controls/md_media_controls-Swift.h>

@implementation MdMediaControlsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMdMediaControlsPlugin registerWithRegistrar:registrar];
}
@end
