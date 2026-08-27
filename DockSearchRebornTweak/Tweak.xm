#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>
#import <objc/runtime.h>

// DockSearch Reborn: adds a raisable search bar to the SpringBoard dock.
// Rootless/roothide port of Ginsu's DockSearch (https://github.com/ginsudev/DockSearch).

#pragma mark - Private class declarations (from the Orion port's Tweak.h)

struct SBIconImageInfo {
    CGSize size;
    double scale;
    double continuousCornerRadius;
};

@interface SBIcon : NSObject
@property (nonatomic, copy, readonly) NSString *displayName;
- (UIImage *)generateIconImageWithInfo: (struct SBIconImageInfo)info;
@end

@interface SBIconModel : NSObject
- (SBIcon *)expectedIconForDisplayIdentifier: (id)identifier;
@end

@interface SBIconController : NSObject
@property (nonatomic, retain) SBIconModel *model;
+ (instancetype)sharedInstance;
@end

@interface SBApplication : NSObject
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier: (NSString *)identifier;
@end

@interface SearchUIDefaultBrowserAppIconImage : NSObject
+ (NSString *)defaultBrowserBundleIdentifier;
@end

@interface SBIconScrollView : UIScrollView
@end

@interface SBHFeatherBlurView : UIView
@end

@interface SBHSearchTextField : UISearchTextField
- (void)setAlignmentBehavior: (long long)behavior animated: (BOOL)animated;
- (CGRect)_frameForLeftViewWithinBounds: (CGRect)bounds alignment: (long long)alignment;
@end

@interface SBHSearchBar : UIView
@property (nonatomic, retain) SBHSearchTextField *searchTextField;
@property (nonatomic, readonly) SBHFeatherBlurView *backgroundView;
- (instancetype)initWithFrame: (CGRect)frame;
- (BOOL)canResignFirstResponder;
- (BOOL)textFieldShouldReturn: (id)field;
- (void)textFieldDidBeginEditing: (id)field;
- (void)textFieldDidEndEditing: (id)field;
- (BOOL)resignFirstResponder;
- (void)_cancelButtonWasHit: (id)sender;
- (void)setShowsCancelButton: (BOOL)shows animated: (BOOL)animated;
@end

@interface SBDockIconListView : UIView
@property (nonatomic, assign, readwrite) UIEdgeInsets additionalLayoutInsets;
@property (nonatomic, copy, readwrite) NSString *iconLocation;
@end

@interface SBRootFolderDockIconListView : SBDockIconListView
@end

@interface SBDockView : UIView
@end

@interface SBRootFolderView : UIView
@end

@interface SBFolderController : UIViewController
@property (nonatomic, readonly) SBDockIconListView *dockIconListView;
@end

@interface SBRootFolderController : SBFolderController
@end

@interface MTMaterialView : UIView
@end

@interface SBSearchScrollView : UIView
@end

@interface CSCoverSheetViewController : UIViewController
@end

@interface SBIconListPageControl : UIPageControl
@property (nonatomic, weak, readwrite) id delegate;
- (void)_setCustomVerticalPadding: (CGFloat)padding;
@end

@interface UIView (DSRPrivate)
- (void)mt_removeAllVisualStyling;
@end

@interface SpringBoard : UIApplication
+ (id)sharedApplication;
- (BOOL)launchApplicationWithIdentifier: (id)identifier suspended: (BOOL)suspended;
@end

#pragma mark - Preferences

static HBPreferences *dsr_preferences;
static BOOL dsr_enabled;
static NSString *dsr_searchPrefix;
static CGFloat dsr_backgroundOpacity;
static BOOL dsr_bottomSearch;
static CGFloat dsr_verticalOffset;

#pragma mark - Raw ivar access

// SBDockView carries a private MTMaterialView ivar (_backgroundView) not
// exposed by any property - the original Swift used Orion's Ivars<T>()
// helper for exactly this. object_getIvar() by name is the standard
// Theos/Logos equivalent.
static id dsr_ivar(id object, const char *name) {
    if (!object) {
        return nil;
    }
    Ivar ivar = class_getInstanceVariable([object class], name);
    return ivar ? object_getIvar(object, ivar) : nil;
}

// Walks up from a view until it finds its enclosing SBDockView. Shared by
// viewDidLoad (to parent the search bar directly under the dock instead of
// inside the icon list, which clips its subviews) and DSSearchBar's own
// dsr_dockView (which needs the same climb from the search bar itself).
static SBDockView *dsr_findDockView(UIView *view) {
    UIView *ancestor = view;
    while (ancestor && ![ancestor isKindOfClass: [SBDockView class]]) {
        ancestor = ancestor.superview;
    }
    return (SBDockView *) ancestor;
}

#pragma mark - DSManager (shared state)

@class DSSearchBar;

@interface DSManager : NSObject
@property (nonatomic, strong) DSSearchBar *searchBar;
@property (nonatomic, strong) UIView *backdropView;
@property (nonatomic, assign) BOOL isRaised;
@property (nonatomic, assign) BOOL isFloatingDock;
+ (instancetype)sharedInstance;
- (NSString *)browserIdentifier;
- (UIImage *)iconFromBundleID: (NSString *)bundleID;
@end

@implementation DSManager

+ (instancetype)sharedInstance {
    static DSManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DSManager alloc] init];
    });
    return shared;
}

- (NSString *)browserIdentifier {
    // Returns the bundle identifier for the device's default browser.
    if ([dsr_searchPrefix containsString: @"youtube"]) {
        return @"com.google.ios.youtube";
    }
    return [SearchUIDefaultBrowserAppIconImage defaultBrowserBundleIdentifier];
}

- (UIImage *)iconFromBundleID: (NSString *)bundleID {
    // Returns a UIImage of an app's icon.
    SBIcon *icon = [[[SBIconController sharedInstance] model] expectedIconForDisplayIdentifier: bundleID];
    struct SBIconImageInfo info;
    info.size = CGSizeMake(60, 60);
    info.scale = UIScreen.mainScreen.scale;
    info.continuousCornerRadius = 12;
    UIImage *img = [icon generateIconImageWithInfo: info];
    return img ?: [UIImage systemImageNamed: @"questionmark.square.fill"];
}

@end

#pragma mark - DSBrowserButton

@interface DSBrowserButton : UIButton
@end

@implementation DSBrowserButton

- (instancetype)initWithFrame: (CGRect)frame {
    self = [super initWithFrame: frame];
    if (self) {
        // Set the button's image to the device's default browser icon.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setImage: [DSManager.sharedInstance iconFromBundleID: DSManager.sharedInstance.browserIdentifier]
                   forState: UIControlStateNormal];
        });
        [self addTarget: self action: @selector(dsr_openCurrentBrowser) forControlEvents: UIControlEventTouchUpInside];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Fix colouring issues on our custom browser icon/button.
    [self mt_removeAllVisualStyling];
}

- (void)dsr_openCurrentBrowser {
    SpringBoard *springboard = (SpringBoard *) [UIApplication sharedApplication];
    [springboard launchApplicationWithIdentifier: DSManager.sharedInstance.browserIdentifier suspended: NO];
}

@end

#pragma mark - DSSearchBar

@interface DSSearchBar : SBHSearchBar
- (void)dsr_searchWithText: (NSString *)text;
- (void)dsr_dismiss;
- (void)dsr_animateWithContext: (NSInteger)context;
- (void)textFieldDidEndEditing: (id)field;
- (void)dsr_wireCancelButton;
- (void)dsr_handleTapOutside: (UITapGestureRecognizer *)recognizer;
- (NSString *)dsr_displayNameForCurrentBrowser;
- (SBDockView *)dsr_dockView;
- (void)dsr_applyBackgroundOpacity;
@end

@implementation DSSearchBar

- (instancetype)initWithFrame: (CGRect)frame {
    self = [super initWithFrame: frame];
    if (self) {
        // Override the magnifying glass icon with our custom browser icon/button.
        self.searchTextField.leftView = [[DSBrowserButton alloc] initWithFrame: [self.searchTextField _frameForLeftViewWithinBounds: self.searchTextField.bounds alignment: 1]];
        // Make the placeholder text show the name of the browser.
        self.searchTextField.placeholder = [self dsr_displayNameForCurrentBrowser];
        // Make everything left-aligned.
        [self.searchTextField setAlignmentBehavior: 1 animated: NO];
    }
    return self;
}

- (BOOL)textFieldShouldReturn: (id)field {
    // Search for the text we entered, then dismiss the search bar
    // (textFieldDidEndEditing: clears the text as part of that dismiss).
    [self dsr_searchWithText: self.searchTextField.text];
    [self dsr_dismiss];
    return [super textFieldShouldReturn: field];
}

- (void)_cancelButtonWasHit: (id)sender {
    // Kept as a harmless fallback, but confirmed (via an on-device view-tree
    // dump) that Apple's Cancel button never actually routes through this -
    // dsr_wireCancelButton below is the real fix.
    [self dsr_dismiss];
    [super _cancelButtonWasHit: sender];
}

- (void)textFieldDidBeginEditing: (id)field {
    // Raise the dock when typing begins.
    [super textFieldDidBeginEditing: field];
    [self dsr_animateWithContext: 1];
    [self dsr_wireCancelButton];
    // The Cancel button isn't always installed by the time this returns -
    // setShowsCancelButton: sometimes finishes its own animation slightly
    // later, so retry once it's had time to actually appear.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dsr_wireCancelButton];
    });
}

- (void)dsr_wireCancelButton {
    // Apple's Cancel button is a plain UIButton, a direct subview of the
    // search bar, whose internal target/action never reaches any override
    // this tweak has - confirmed by dumping the actual view tree on-device.
    // Wiring our own target directly onto it is independent of whatever
    // Apple wired underneath: a UIButton accepts multiple targets for the
    // same event without conflict. removeTarget: first keeps this idempotent
    // across repeated calls (immediate + delayed retry above).
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass: [UIButton class]]) {
            UIButton *button = (UIButton *) subview;
            [button removeTarget: self action: @selector(dsr_dismiss) forControlEvents: UIControlEventTouchUpInside];
            [button addTarget: self action: @selector(dsr_dismiss) forControlEvents: UIControlEventTouchUpInside];
        }
    }
}

- (void)dsr_handleTapOutside: (UITapGestureRecognizer *)recognizer {
    // There's no built-in "tap outside dismisses" behaviour on the home
    // screen the way there would be in a normal app - this gesture
    // recognizer (added once, to the whole root folder view, in viewDidLoad)
    // is what makes tapping elsewhere behave like Cancel. cancelsTouchesInView
    // is NO so it never blocks the tap it's observing from also reaching
    // whatever's actually underneath (an icon, the wallpaper, etc).
    if (!DSManager.sharedInstance.isRaised) {
        return;
    }
    CGPoint location = [recognizer locationInView: self];
    if (CGRectContainsPoint(self.bounds, location)) {
        // Tap landed on the bar itself (or its Cancel/x buttons) - let
        // their own handling deal with it, don't double-dismiss.
        return;
    }
    [self dsr_dismiss];
}

- (void)textFieldDidEndEditing: (id)field {
    // Fires whenever the field loses first-responder status for any reason,
    // including tapping outside the bar (which doesn't route through
    // _cancelButtonWasHit:) - so this is the one place that makes "tap
    // outside" behave exactly like Cancel: same dismiss, same cleared text.
    // dsr_dismiss's own resignFirstResponder is a harmless no-op here since
    // the field is already resigning by the time this fires.
    [super textFieldDidEndEditing: field];
    self.searchTextField.text = nil;
    [self dsr_dismiss];
}

- (void)didAddSubview: (UIView *)subview {
    [super didAddSubview: subview];

    // Remove this annoying view that plagues devices with a random blurry bar at the top of the screen...
    if (subview == self.backgroundView) {
        [subview removeFromSuperview];
    }

    if (subview == self.searchTextField) {
        [self dsr_applyBackgroundOpacity];
    }
}

- (void)dsr_applyBackgroundOpacity {
    // dsr_backgroundOpacity is a 0-1 slider (Root.plist), not the on/off
    // switch the original had - alpha instead of removeFromSuperview so it
    // can be dialed live. Called again from viewWillAppear: (not just here,
    // where it only ever runs once per search bar) so moving the slider and
    // returning to the home screen actually takes effect without a
    // respring, same as the other appearance settings.
    for (UIView *view in self.searchTextField.subviews) {
        if ([view isKindOfClass: [MTMaterialView class]]) {
            view.alpha = dsr_backgroundOpacity;
        }
    }
}

- (void)dsr_searchWithText: (NSString *)text {
    // Search for the text the user inputted.
    if (text.length == 0) {
        return;
    }

    NSString *encoded = [text stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *urlFromEncoded = [NSURL URLWithString: encoded ?: @""];

    if (urlFromEncoded && urlFromEncoded.scheme && urlFromEncoded.host) {
        [[UIApplication sharedApplication] openURL: urlFromEncoded options: @{} completionHandler: nil];
    } else {
        NSString *urlText = [encoded stringByReplacingOccurrencesOfString: @"+" withString: @"%2b"];
        NSURL *url = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@", dsr_searchPrefix, urlText]];
        [[UIApplication sharedApplication] openURL: url options: @{} completionHandler: nil];
    }
}

- (void)dsr_dismiss {
    // Dismiss the keyboard, dock and hide the cancel button.
    [self resignFirstResponder];
    [self setShowsCancelButton: NO animated: YES];
    [self dsr_animateWithContext: 0];
}

- (void)dsr_animateWithContext: (NSInteger)context {
    // Context types: 1 = raise the search bar, 0 = lower the search bar.
    CGAffineTransform transformation;
    if (context == 1) {
        DSManager.sharedInstance.isRaised = YES;
        SBDockView *dockView = [self dsr_dockView];
        transformation = CGAffineTransformMakeTranslation(0, -(UIScreen.mainScreen.bounds.size.height - dockView.frame.size.height) + 100);
    } else {
        DSManager.sharedInstance.isRaised = NO;
        transformation = CGAffineTransformIdentity;
    }
    CGAffineTransform counterTransformation = CGAffineTransformInvert(transformation);

    [UIView animateWithDuration: 0.4 delay: 0.0 usingSpringWithDamping: 0.8 initialSpringVelocity: 0.4 options: UIViewAnimationOptionCurveEaseInOut animations: ^{
        // Moves the whole SBDockView (proven safe for Cancel/tap-outside -
        // the search bar's own position relative to its clipping parent,
        // dockIconListView, never changes, so it never loses touches).
        [self dsr_dockView].transform = transformation;
        // ...then cancels that movement on every OTHER view sharing the
        // search bar's immediate parent (dockIconListView - the icons),
        // so the icons visually stay put while the bar, left untouched
        // here, still inherits the dock's own transform and rises with it.
        // The search bar itself is never reparented and its own transform
        // is never touched - a previous attempt that moved the bar itself
        // (self.transform) broke Cancel by changing its hierarchy; this
        // achieves the same visual result without going anywhere near that.
        for (UIView *sibling in self.superview.subviews) {
            if (sibling != self) {
                sibling.transform = counterTransformation;
            }
        }
        DSManager.sharedInstance.backdropView.alpha = (context == 1) ? 0.6 : 0.0;
    } completion: nil];
}

- (NSString *)dsr_displayNameForCurrentBrowser {
    // Returns a string to be shown as a placeholder on the search bar.
    SBApplication *application = [[SBApplicationController sharedInstance] applicationWithBundleIdentifier: DSManager.sharedInstance.browserIdentifier];
    return application.displayName ?: @"Search";
}

- (SBDockView *)dsr_dockView {
    // Compatibility with some other dock tweaks like Multipla, which nest
    // things differently - climb rather than assume a fixed depth.
    return dsr_findDockView(self.superview);
}

@end

#pragma mark - Dock modification and search bar init

%hook SBRootFolderController

- (void)viewDidLoad {
    %orig;

    if (!dsr_enabled) {
        return;
    }

    // Check if iPad's floating dock is enabled. Don't progress any further if it is.
    DSManager.sharedInstance.isFloatingDock = [self.dockIconListView.iconLocation isEqualToString: @"SBIconLocationFloatingDock"];

    if (DSManager.sharedInstance.isFloatingDock) {
        return;
    }

    // Full-screen dim, faded in/out by DSSearchBar's own raise/dismiss
    // animation - inserted at index 0 so it sits behind everything already
    // in self.view (icons, dock) without needing to know exactly where in
    // that hierarchy the dock itself lives. userInteractionEnabled = NO so
    // it never intercepts the tap-outside gesture recognizer below it.
    // A plain dim, not a real UIVisualEffectView blur: the wallpaper lives
    // in a separate window behind this one, and real-time blur can't
    // sample across windows - it rendered as flat grey with nothing of its
    // own window to blur, confirmed on-device.
    UIView *dsrBackdrop = [[UIView alloc] initWithFrame: self.view.bounds];
    dsrBackdrop.backgroundColor = [UIColor blackColor];
    dsrBackdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dsrBackdrop.userInteractionEnabled = NO;
    dsrBackdrop.alpha = 0.0;
    DSManager.sharedInstance.backdropView = dsrBackdrop;
    [self.view insertSubview: dsrBackdrop atIndex: 0];

    // Init and add the search bar.
    DSManager.sharedInstance.searchBar = [[DSSearchBar alloc] initWithFrame: CGRectMake(15, 22, self.dockIconListView.frame.size.width - 30, 40)];
    [self.dockIconListView addSubview: DSManager.sharedInstance.searchBar];

    // Tapping anywhere outside the bar while it's raised dismisses it, same
    // as Cancel. cancelsTouchesInView = NO so this never blocks the tap it
    // observes from also reaching whatever's underneath.
    UITapGestureRecognizer *dsrTapOutside = [[UITapGestureRecognizer alloc] initWithTarget: DSManager.sharedInstance.searchBar action: @selector(dsr_handleTapOutside:)];
    dsrTapOutside.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer: dsrTapOutside];
}

- (void)viewWillAppear: (BOOL)animated {
    %orig;

    if (!dsr_enabled || DSManager.sharedInstance.isFloatingDock || !DSManager.sharedInstance.searchBar) {
        return;
    }

    MTMaterialView *rawBackgroundView = dsr_ivar([DSManager.sharedInstance.searchBar dsr_dockView], "_backgroundView");
    CGRect backgroundFrame = rawBackgroundView.frame;

    // Set frame. dsr_verticalOffset (Root.plist slider, points, +down/-up)
    // nudges within whichever base position (above/below) is selected below
    // - the layout insets stay tied to the base position only, not the
    // nudge, so other dock icons don't shuffle around for a small offset.
    if (dsr_bottomSearch) {
        DSManager.sharedInstance.searchBar.frame = CGRectMake(15, backgroundFrame.size.height - 62 + dsr_verticalOffset, backgroundFrame.size.width - 30, 40);
        self.dockIconListView.additionalLayoutInsets = UIEdgeInsetsMake(0, 0, 60, 0);
    } else {
        DSManager.sharedInstance.searchBar.frame = CGRectMake(15, 22 + dsr_verticalOffset, backgroundFrame.size.width - 30, 40);
        self.dockIconListView.additionalLayoutInsets = UIEdgeInsetsMake(60, 0, 0, 0);
    }

    // Live-apply the opacity slider too - didAddSubview: only runs once,
    // when the background view is first added, so a slider change alone
    // wouldn't otherwise show up until the next respring.
    [DSManager.sharedInstance.searchBar dsr_applyBackgroundOpacity];

    if ([[NSFileManager defaultManager] fileExistsAtPath: @"/Library/MobileSubstrate/DynamicLibraries/Multipla.dylib"]) {
        return;
    }

    // Horizontally centre the search bar.
    CGPoint center = DSManager.sharedInstance.searchBar.center;
    DSManager.sharedInstance.searchBar.center = CGPointMake(self.view.center.x, center.y);
}

%end

%hook SBDockView

// Make the dock taller.
- (CGFloat)dockHeight {
    if (!dsr_enabled) {
        return %orig;
    }
    return %orig + 60;
}

%end

#pragma mark - Shift and shrink the page dots

%hook SBIconListPageControl

- (void)didMoveToWindow {
    %orig;

    if (!dsr_enabled || DSManager.sharedInstance.isFloatingDock) {
        return;
    }

    if (![self.delegate isKindOfClass: [SBRootFolderView class]]) {
        return;
    }

    // The original compensated this offset when Ginsu's AndroBar was also
    // installed, via a shared library (com.ginsu.libgscommon) that has no
    // rootless build - dropped rather than guess at a replacement height.
    self.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    [self _setCustomVerticalPadding: 5];
}

%end

#pragma mark - Dismissing in particular circumstances

%hook SBIconScrollView

// Dismiss the dock when scrolling home screen pages.
- (void)_bs_willBeginScrolling {
    %orig;

    if (!dsr_enabled || DSManager.sharedInstance.isFloatingDock || !DSManager.sharedInstance.isRaised) {
        return;
    }

    [DSManager.sharedInstance.searchBar dsr_dismiss];
}

%end

%hook CSCoverSheetViewController

// If the user locked the device while the dock was raised, dismiss it before the next unlock.
- (void)viewWillDisappear: (BOOL)animated {
    %orig;

    if (!dsr_enabled || DSManager.sharedInstance.isFloatingDock || !DSManager.sharedInstance.isRaised) {
        return;
    }

    [DSManager.sharedInstance.searchBar dsr_dismiss];
}

%end

%hook SBSearchScrollView

// Prevent access to the (swipe down) spotlight search when the dock is raised.
- (BOOL)gestureRecognizerShouldBegin: (UIGestureRecognizer *)gestureRecognizer {
    if (dsr_enabled && DSManager.sharedInstance.isRaised) {
        return NO;
    }
    return %orig;
}

%end

%hook SpringBoard

// Dismiss the dock when opening apps.
- (void)frontDisplayDidChange: (id)display {
    %orig;

    if (!dsr_enabled || DSManager.sharedInstance.isFloatingDock) {
        return;
    }

    if (![display isKindOfClass: [SBApplication class]]) {
        return;
    }

    SBApplication *application = (SBApplication *) display;
    if ([application.bundleIdentifier isEqualToString: @"com.apple.springboard"]) {
        return;
    }

    [DSManager.sharedInstance.searchBar dsr_dismiss];
}

%end

%ctor {
    dsr_preferences = [[HBPreferences alloc] initWithIdentifier: @"com.brkr1.tweaks.docksearchreborn.hbprefs"];
    [dsr_preferences registerDefaults: @{
        @"isEnabled": @YES,
        @"searchPrefix": @"https://www.google.com/search?q=",
        @"backgroundOpacity": @1.0,
        @"bottomSearch": @NO,
        @"verticalOffset": @0.0
    }];

    [dsr_preferences registerBool: &dsr_enabled default: YES forKey: @"isEnabled"];
    [dsr_preferences registerObject: &dsr_searchPrefix default: @"https://www.google.com/search?q=" forKey: @"searchPrefix"];
    [dsr_preferences registerFloat: &dsr_backgroundOpacity default: 1.0 forKey: @"backgroundOpacity"];
    [dsr_preferences registerBool: &dsr_bottomSearch default: NO forKey: @"bottomSearch"];
    [dsr_preferences registerFloat: &dsr_verticalOffset default: 0.0 forKey: @"verticalOffset"];
}
