#import "TracksService.h"
#import "TracksDeviceInformation.h"

@interface TracksService ()

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *eventNamePrefix;
@property (nonatomic, assign, getter=isAnonymous) BOOL anonymous;

@end

static NSTimeInterval const EVENT_TIMER_DEFAULT = 5 * 60;
NSString *const TrackServiceWillSendQueuedEventsNotification = @"TrackServiceDidSendQueuedEventsNotification";
NSString *const TrackServiceDidSendQueuedEventsNotification = @"TrackServiceDidSendQueuedEventsNotification";

@implementation TracksService

- (instancetype)init
{
    self = [super init];
    if (self) {
        _eventNamePrefix = @"wpios_";
        _remote = [TracksServiceRemote new];
        _queueSendInterval = EVENT_TIMER_DEFAULT;
        _contextManager = [TracksContextManager new];
        _tracksEventService = [[TracksEventService alloc] initWithContextManager:_contextManager];
        
        [self switchToAnonymousUser];
        [self resetTimer];
    }
    
    return self;
}

- (void)trackEventName:(NSString *)eventName
{
    NSParameterAssert(eventName.length > 0);
    
    eventName = [NSString stringWithFormat:@"%@%@", self.eventNamePrefix, eventName];
    
    [self.tracksEventService createTracksEventWithName:eventName
                                              username:self.username
                                                userID:self.userID
                                             userAgent:nil
                                              userType:self.isAnonymous ? TracksEventUserTypeAnonymous : TracksEventUserTypeWordPressCom
                                             eventDate:[NSDate date]];
}


- (NSUInteger)queuedEventCount
{
    return [self.tracksEventService numberOfTracksEvents];
}


- (void)sendQueuedEvents
{
    [self.timer invalidate];
    [[NSNotificationCenter defaultCenter] postNotificationName:TrackServiceWillSendQueuedEventsNotification object:nil];
    
    NSArray *events = [self.tracksEventService allTracksEvents];

    if (events.count == 0) {
        NSLog(@"No events to send.");
        [self resetTimer];
        return;
    }
    
    NSDictionary *commonProperties = [self generateCommonProperties];

    NSMutableArray *jsonEvents = [NSMutableArray arrayWithCapacity:events.count];
    for (TracksEvent *tracksEvent in events) {
        NSDictionary *eventJSON = [tracksEvent dictionaryRepresentationWithParentCommonProperties:commonProperties];
        [jsonEvents addObject:eventJSON];
    }
    
    NSLog(@"Sending queued events");
    [self.remote sendBatchOfEvents:jsonEvents
              withSharedProperties:commonProperties
                 completionHandler:^{
                     // Delete the events since they sent or errored
                     [self.tracksEventService removeTracksEvents:events];
                     
                     // Assume no errors for now
                     [self resetTimer];
                     
                     [[NSNotificationCenter defaultCenter] postNotificationName:TrackServiceDidSendQueuedEventsNotification object:nil];
                 }
     ];
}


- (void)switchToAuthenticatedUserWithUsername:(NSString *)username userID:(NSString *)userID skipAliasEventCreation:(BOOL)skipEvent
{
    NSString *previousUsername = self.username;
    
    self.anonymous = NO;
    self.username = username;
    self.userID = userID;
    
    if (skipEvent == NO) {
        [self.tracksEventService createTracksEventForAliasingWordPressComUser:username userID:userID withAnonymousUsername:previousUsername];
    }
}


- (void)switchToAnonymousUser
{
    self.anonymous = YES;
    self.username = @"";
    self.userID = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
}


#pragma mark - Private methods


- (void)resetTimer
{
    [self.timer invalidate];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.queueSendInterval target:self selector:@selector(timerFireMethod:) userInfo:nil repeats:NO];
}


- (void)timerFireMethod:(NSTimer *)timer
{
    [self sendQueuedEvents];
}


- (void)dealloc
{
    [self.timer invalidate];
}


- (void)setQueueSendInterval:(NSTimeInterval)queueSendInterval
{
    _queueSendInterval = queueSendInterval;
    [self resetTimer];
}

- (NSDictionary *)generateCommonProperties
{
    TracksDeviceInformation *deviceInformation = [TracksDeviceInformation new];
    
    NSString *REQUEST_TIMESTAMP_KEY = @"_rt";
    NSString *DEVICE_HEIGHT_PIXELS_KEY = @"_ht";
    NSString *DEVICE_WIDTH_PIXELS_KEY = @"_wd";
    NSString *DEVICE_LANG_KEY = @"_lg";
    NSString *DEVICE_INFO_PREFIX = @"device_info_";
    NSString *deviceInfoAppName = [NSString stringWithFormat:@"%@app_name", DEVICE_INFO_PREFIX];
    NSString *deviceInfoAppVersion = [NSString stringWithFormat:@"%@app_version", DEVICE_INFO_PREFIX];
    NSString *deviceInfoAppBuild = [NSString stringWithFormat:@"%@app_version_code", DEVICE_INFO_PREFIX];
    NSString *deviceInfoOS = [NSString stringWithFormat:@"%@os", DEVICE_INFO_PREFIX];
    NSString *deviceInfoOSVersion = [NSString stringWithFormat:@"%@os_version", DEVICE_INFO_PREFIX];
    NSString *deviceInfoBrand = [NSString stringWithFormat:@"%@brand", DEVICE_INFO_PREFIX];
    NSString *deviceInfoManufacturer = [NSString stringWithFormat:@"%@manufacturer", DEVICE_INFO_PREFIX];
    NSString *deviceInfoModel = [NSString stringWithFormat:@"%@model", DEVICE_INFO_PREFIX];
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    
    // These properties change often and should be overridden in TracksEvents if they differ
    NSString *deviceInfoNetworkOperator = [NSString stringWithFormat:@"%@current_network_operator", DEVICE_INFO_PREFIX];
    NSString *deviceInfoRadioType = [NSString stringWithFormat:@"%@phone_radio_type", DEVICE_INFO_PREFIX];
    NSString *deviceInfoWiFiConnected = [NSString stringWithFormat:@"%@wifi_connected", DEVICE_INFO_PREFIX];

    return @{ REQUEST_TIMESTAMP_KEY : @(lround([NSDate date].timeIntervalSince1970 * 1000)),
              deviceInfoAppBuild : deviceInformation.appBuild ?: @"Unknown",
              deviceInfoAppName : deviceInformation.appName ?: @"Unknown",
              deviceInfoAppVersion : deviceInformation.appVersion ?: @"Unknown",
              deviceInfoBrand : deviceInformation.brand ?: @"Unknown",
              deviceInfoManufacturer : deviceInformation.manufacturer ?: @"Unknown",
              deviceInfoModel : deviceInformation.model ?: @"Unknown",
              deviceInfoOS : deviceInformation.os ?: @"Unknown",
              deviceInfoOSVersion : deviceInformation.version ?: @"Unknown",
              DEVICE_HEIGHT_PIXELS_KEY : @(screenSize.height) ?: @0,
              DEVICE_WIDTH_PIXELS_KEY : @(screenSize.width) ?: @0,
              DEVICE_LANG_KEY : deviceInformation.deviceLanguage ?: @"Unknown",
              TracksUserAgentKey : @"Nosara Client for iOS 0.0.0",
              deviceInfoNetworkOperator : deviceInformation.currentNetworkOperator ?: @"Unknown",
              deviceInfoRadioType : deviceInformation.currentNetworkRadioType ?: @"Unknown",
              deviceInfoWiFiConnected : deviceInformation.isWiFiConnected ? @"YES" : @"NO"
              };
}

@end
