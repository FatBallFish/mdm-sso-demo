#import "include/DemoLoginPlugin.h"

#import <Cocoa/Cocoa.h>
#import <Security/AuthorizationTags.h>
#import <SecurityInterface/SFAuthorizationPluginView.h>
#import <os/log.h>

static NSString * const DemoPluginDefaultIDPBaseURL = @"http://127.0.0.1:48080/";

@interface DemoAuthorizationLoginView : SFAuthorizationPluginView
@property(nonatomic, strong) NSView *containerView;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *subtitleLabel;
@property(nonatomic, strong) NSTextField *usernameField;
@property(nonatomic, strong) NSSecureTextField *passwordField;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSButton *loginButton;
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
    self.containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 394, 188)];

    self.titleLabel = [self labelWithString:@"Demo SSO Sign In" font:[NSFont boldSystemFontOfSize:20.0] color:NSColor.labelColor];
    self.titleLabel.frame = NSMakeRect(0, 150, 394, 24);
    [self.containerView addSubview:self.titleLabel];

    self.subtitleLabel = [self labelWithString:@"Use your demo SSO account before macOS continues the local login flow." font:[NSFont systemFontOfSize:12.0] color:NSColor.secondaryLabelColor];
    self.subtitleLabel.frame = NSMakeRect(0, 128, 394, 18);
    [self.containerView addSubview:self.subtitleLabel];

    self.usernameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 88, 394, 24)];
    self.usernameField.placeholderString = @"SSO username";
    [self.containerView addSubview:self.usernameField];

    self.passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 54, 394, 24)];
    self.passwordField.placeholderString = @"SSO password";
    [self.containerView addSubview:self.passwordField];

    self.statusLabel = [self labelWithString:@"The plugin checks the local HTTP IdP first, then falls back to seeded demo accounts." font:[NSFont systemFontOfSize:11.0] color:NSColor.secondaryLabelColor];
    self.statusLabel.frame = NSMakeRect(0, 20, 394, 26);
    self.statusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.statusLabel.maximumNumberOfLines = 2;
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

- (void)didActivate {
    [super didActivate];
    [self setButton:SFButtonTypeLogin enabled:YES];
    [self setButton:SFButtonTypeCancel enabled:YES];
}

- (NSView *)viewForType:(SFViewType)inType {
    (void)inType;
    return self.containerView;
}

- (NSResponder *)firstResponder {
    return self.usernameField;
}

- (NSView *)firstKeyView {
    return self.usernameField;
}

- (NSView *)lastKeyView {
    return self.passwordField;
}

- (void)setEnabled:(BOOL)inEnabled {
    [self.usernameField setEnabled:inEnabled];
    [self.passwordField setEnabled:inEnabled];
    [self setButton:SFButtonTypeLogin enabled:inEnabled];
    [self setButton:SFButtonTypeCancel enabled:inEnabled];
}

- (void)buttonPressed:(SFButtonType)inButtonType {
    switch (inButtonType) {
        case SFButtonTypeCancel:
            DemoPluginSetAuthorizationResult([self callbacks], [self engineRef], kAuthorizationResultUserCanceled);
            return;
        case SFButtonTypeLogin:
            break;
    }

    NSString *username = self.usernameField.stringValue ?: @"";
    NSString *password = self.passwordField.stringValue ?: @"";
    if (username.length == 0 || password.length == 0) {
        [self showError:@"Enter both username and password."];
        return;
    }

    [self setEnabled:NO];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel.stringValue = @"Authenticating...";

    [self validateUsername:username password:password];
}

- (void)validateUsername:(NSString *)username password:(NSString *)password {
    NSURL *baseURL = [self idpBaseURL];
    NSURL *healthURL = [baseURL URLByAppendingPathComponent:@"api/health"];
    NSURLSession *session = [NSURLSession sharedSession];
    os_log_info([self logger], "pre-login auth attempt username=%{public}s", username.UTF8String);

    [[session dataTaskWithURL:healthURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        (void)data;
        BOOL healthOK = NO;
        if (error == nil && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            healthOK = (((NSHTTPURLResponse *)response).statusCode == 200);
        }

        if (healthOK) {
            os_log_info([self logger], "auth_source=http health=ok username=%{public}s", username.UTF8String);
            [self performHTTPLoginWithSession:session baseURL:baseURL username:username password:password];
        } else {
            os_log_info([self logger], "auth_source=fallback reason=service_unavailable username=%{public}s", username.UTF8String);
            [self completeWithFallbackForUsername:username password:password];
        }
    }] resume];
}

- (void)performHTTPLoginWithSession:(NSURLSession *)session
                            baseURL:(NSURL *)baseURL
                           username:(NSString *)username
                           password:(NSString *)password {
    NSURL *loginURL = [baseURL URLByAppendingPathComponent:@"api/login"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:loginURL];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSData *body = [NSJSONSerialization dataWithJSONObject:@{
        @"username": username,
        @"password": password,
    } options:0 error:nil];
    request.HTTPBody = body;

    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error == nil && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (http.statusCode == 200 && data != nil) {
                NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *localShortName = [payload isKindOfClass:[NSDictionary class]] ? payload[@"localShortName"] : nil;
                if (localShortName.length > 0) {
                    os_log_info([self logger], "auth_source=http result=allow localShortName=%{public}s", localShortName.UTF8String);
                    [self completeAllowWithLocalShortName:localShortName password:password];
                    return;
                }
            }

            if (http.statusCode == 401) {
                os_log_info([self logger], "auth_source=fallback reason=http_invalid_credentials username=%{public}s", username.UTF8String);
                [self completeWithFallbackForUsername:username password:password];
                return;
            }
        }

        os_log_info([self logger], "auth_source=fallback reason=unexpected_error username=%{public}s", username.UTF8String);
        [self completeWithFallbackForUsername:username password:password];
    }] resume];
}

- (void)completeWithFallbackForUsername:(NSString *)username password:(NSString *)password {
    NSDictionary *account = [self seededAccountForUsername:username password:password];
    if (account != nil) {
        NSString *localShortName = account[@"localShortName"];
        os_log_info([self logger], "auth_source=fallback result=allow localShortName=%{public}s", localShortName.UTF8String);
        [self completeAllowWithLocalShortName:localShortName password:password];
        return;
    }

    os_log_error([self logger], "auth_source=fallback result=deny username=%{public}s", username.UTF8String);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setEnabled:YES];
        self.statusLabel.textColor = NSColor.systemRedColor;
        self.statusLabel.stringValue = @"SSO authentication failed.";
    });
}

- (NSDictionary *)seededAccountForUsername:(NSString *)username password:(NSString *)password {
    NSArray<NSDictionary *> *accounts = @[
        @{@"username": @"demo.user", @"password": @"DemoPass123!", @"localShortName": @"demouser"},
        @{@"username": @"it.admin", @"password": @"AdminPass123!", @"localShortName": @"itadmin"},
        @{@"username": @"qa.user", @"password": @"QAPass123!", @"localShortName": @"qauser"},
    ];

    for (NSDictionary *account in accounts) {
        if ([account[@"username"] isEqualToString:username] && [account[@"password"] isEqualToString:password]) {
            return account;
        }
    }

    return nil;
}

- (NSURL *)idpBaseURL {
    NSString *value = NSProcessInfo.processInfo.environment[@"DEMO_LOGIN_PLUGIN_IDP_BASE_URL"];
    if (value.length == 0) {
        value = DemoPluginDefaultIDPBaseURL;
    }
    return [NSURL URLWithString:value];
}

- (void)completeAllowWithLocalShortName:(NSString *)localShortName password:(NSString *)password {
    dispatch_async(dispatch_get_main_queue(), ^{
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
