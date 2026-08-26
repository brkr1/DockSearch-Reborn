#import "DockSearchRebornPrefsController.h"

// No respring needed - Tweak.xm's registerPreferenceChangeBlock reacts to
// changes made here immediately.

@implementation DockSearchRebornPrefsController
    + (nullable NSString*) hb_specifierPlist {
        return @"Root";
    }

    - (nullable NSString*) hb_specifierPlist {
        return @"Root";
    }
@end
