#import "include/DemoLoginPlugin.h"

#import <Cocoa/Cocoa.h>
#import <Security/AuthorizationTags.h>
#import <SecurityInterface/SFAuthorizationPluginView.h>
#import <os/log.h>

@interface DemoAuthorizationLoginView : SFAuthorizationPluginView
@property(nonatomic, strong) NSView *containerView;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *subtitleLabel;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSButton *successButton;
@property(nonatomic, strong) NSButton *failureButton;
@property(nonatomic, strong) NSButton *cancelButton;
@end

@implementation DemoAuthorizationLoginView

- (instancetype)initWithCallbacks:(const AuthorizationCallbacks *)callbacks andEngineRef:(AuthorizationEngineRef)engineRef {
    self = [super initWithCallbacks:callbacks andEngineRef:engineRef];
    if (self != nil) {
        [self buildViewHierarchy];
    }
    return self;
}

- (void)buildViewHierarchy {
    self.containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 394, 220)];

    self.titleLabel = [self labelWithString:@"Demo SSO Sign In" font:[NSFont boldSystemFontOfSize:20.0] color:NSColor.labelColor];
    self.titleLabel.frame = NSMakeRect(0, 182, 394, 24);
    [self.containerView addSubview:self.titleLabel];

    self.subtitleLabel = [self labelWithString:@"Use the buttons below to verify that the plug-in can allow, deny, or return to the native macOS login screen." font:[NSFont systemFontOfSize:12.0] color:NSColor.secondaryLabelColor];
    self.subtitleLabel.frame = NSMakeRect(0, 144, 394, 34);
    self.subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.subtitleLabel.maximumNumberOfLines = 2;
    [self.containerView addSubview:self.subtitleLabel];

    self.successButton = [self actionButtonWithTitle:@"Validate Success" action:@selector(validateSuccessPressed:)];
    self.successButton.frame = NSMakeRect(0, 102, 180, 30);
    [self.containerView addSubview:self.successButton];

    self.failureButton = [self actionButtonWithTitle:@"Validate Failure" action:@selector(validateFailurePressed:)];
    self.failureButton.frame = NSMakeRect(0, 66, 180, 30);
    [self.containerView addSubview:self.failureButton];

    self.cancelButton = [self actionButtonWithTitle:@"Back To macOS Login" action:@selector(cancelPressed:)];
    self.cancelButton.frame = NSMakeRect(0, 30, 180, 30);
    [self.containerView addSubview:self.cancelButton];

    self.statusLabel = [self labelWithString:@"Choose a demo action. No text input is used in this loginwindow-hosted view." font:[NSFont systemFontOfSize:11.0] color:NSColor.secondaryLabelColor];
    self.statusLabel.frame = NSMakeRect(196, 28, 198, 76);
    self.statusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.statusLabel.maximumNumberOfLines = 4;
    [self.containerView addSubview:self.statusLabel];
}

- (NSTextField *)labelWithString:(NSString *)string font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSZeroRect];
    label.stringValue = string;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.selectable = NO;
    label.font = font;
    label.textColor = color;
    return label;
}

- (NSButton *)actionButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:NSZeroRect];
    button.title = title;
    button.target = self;
    button.action = action;
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}

- (void)didActivate {
    [super didActivate];
    [self setButton:SFButtonTypeLogin enabled:NO];
    [self setButton:SFButtonTypeCancel enabled:NO];
}

- (NSView *)viewForType:(SFViewType)inType {
    (void)inType;
    return self.containerView;
}

- (NSResponder *)firstResponder {
    return self.successButton;
}

- (NSView *)firstKeyView {
    return self.successButton;
}

- (NSView *)lastKeyView {
    return self.cancelButton;
}

- (void)setEnabled:(BOOL)inEnabled {
    [self.successButton setEnabled:inEnabled];
    [self.failureButton setEnabled:inEnabled];
    [self.cancelButton setEnabled:inEnabled];
    [self setButton:SFButtonTypeLogin enabled:NO];
    [self setButton:SFButtonTypeCancel enabled:NO];
}

- (void)validateSuccessPressed:(id)sender {
    (void)sender;
    os_log_info([self logger], "pre-login validate success pressed");
    [self setEnabled:NO];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel.stringValue = @"Applying demo credentials...";
    [self completeAllowWithLocalShortName:@"demouser" password:@"DemoPass123!"];
}

- (void)validateFailurePressed:(id)sender {
    (void)sender;
    os_log_info([self logger], "pre-login validate failure pressed");
    [self showError:@"Demo validation failed."];
}

- (void)cancelPressed:(id)sender {
    (void)sender;
    os_log_info([self logger], "pre-login cancel pressed");
    DemoPluginSetAuthorizationResult([self callbacks], [self engineRef], kAuthorizationResultUserCanceled);
}

- (void)completeAllowWithLocalShortName:(NSString *)localShortName password:(NSString *)password {
    dispatch_async(dispatch_get_main_queue(), ^{
        os_log_info([self logger], "pre-login validate success applying credentials localShortName=%{public}s", localShortName.UTF8String);
        OSStatus status = DemoPluginApplyCredentials([self callbacks], [self engineRef], localShortName.UTF8String, password.UTF8String);
        if (status != errAuthorizationSuccess) {
            [self showError:@"Failed to hand credentials to macOS login chain."];
            return;
        }

        DemoPluginSetAuthorizationResult([self callbacks], [self engineRef], kAuthorizationResultAllow);
    });
}

- (void)showError:(NSString *)message {
    [self setEnabled:YES];
    self.statusLabel.textColor = NSColor.systemRedColor;
    self.statusLabel.stringValue = message;
}

- (os_log_t)logger {
    static os_log_t logger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = os_log_create("com.demo.sso.login-plugin", "prelogin-ui");
    });
    return logger;
}

@end

void *DemoPluginCreateLoginView(const AuthorizationCallbacks *callbacks, AuthorizationEngineRef engine) {
    NSString *forcedFailure = NSProcessInfo.processInfo.environment[@"DEMO_PLUGIN_FORCE_VIEW_CREATE_FAILURE"];
    if (forcedFailure.length > 0) {
        return NULL;
    }

    DemoAuthorizationLoginView *view = [[DemoAuthorizationLoginView alloc] initWithCallbacks:callbacks andEngineRef:engine];
    return (__bridge_retained void *)view;
}

OSStatus DemoPluginDisplayLoginView(void *viewHandle) {
    if (viewHandle == NULL) {
        return errAuthorizationInternal;
    }

    @try {
        DemoAuthorizationLoginView *view = (__bridge DemoAuthorizationLoginView *)viewHandle;
        [view displayView];
        return errAuthorizationSuccess;
    } @catch (NSException *exception) {
        os_log_error(os_log_create("com.demo.sso.login-plugin", "prelogin-ui"), "displayView exception=%{public}s", exception.reason.UTF8String);
        return errAuthorizationInternal;
    }
}

void DemoPluginDeactivateLoginView(void *viewHandle) {
    if (viewHandle == NULL) {
        return;
    }

    DemoAuthorizationLoginView *view = (__bridge DemoAuthorizationLoginView *)viewHandle;
    [view didDeactivate];
}

void DemoPluginDestroyLoginView(void *viewHandle) {
    if (viewHandle == NULL) {
        return;
    }

    (void)(__bridge_transfer DemoAuthorizationLoginView *)viewHandle;
}
