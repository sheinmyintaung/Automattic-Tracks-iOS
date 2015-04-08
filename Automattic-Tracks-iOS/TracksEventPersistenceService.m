#import "TracksEventPersistenceService.h"
#import "TracksEventCoreData.h"

@interface TracksEventPersistenceService ()

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation TracksEventPersistenceService

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self = [self init];
    if (self) {
        _managedObjectContext = managedObjectContext;
    }
    return self;
}


- (void)persistTracksEvent:(TracksEvent *)tracksEvent
{
    [self.managedObjectContext performBlockAndWait:^{
        [self createTracksEventCoreDataWithTracksEvent:tracksEvent];
        
        [self saveManagedObjectContext];
    }];
}


- (NSArray *)fetchAllTracksEvents
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"TracksEvent"];
    
    NSError *error;
    NSArray *results = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if (error) {
        NSLog(@"Error while fetching all TracksEvent: %@", error);
        return nil;
    }
    
    NSMutableArray *transformedResults = [[NSMutableArray alloc] initWithCapacity:results.count];
    for (TracksEventCoreData *eventCoreData in results) {
        TracksEvent *tracksEvent = [self mapToTracksEventWithTracksEventCoreData:eventCoreData];
        [transformedResults addObject:tracksEvent];
    }
    
    return transformedResults;
}


- (NSUInteger)countAllTracksEvents
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"TracksEvent"];
    
    NSError *error;
    NSUInteger count = [self.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    
    if (error) {
        NSLog(@"Error while fetching count of TracksEvent: %@", error);
    }
    
    return count;
}


- (void)removeTracksEvents:(NSArray *)tracksEvents
{
    [self.managedObjectContext performBlockAndWait:^{
        for (TracksEvent *tracksEvent in tracksEvents) {
            TracksEventCoreData *tracksEventCoreData = [self findTracksEventCoreDataWithUUID:tracksEvent.uuid];
            
            [self.managedObjectContext deleteObject:tracksEventCoreData];
        }
        
        [self saveManagedObjectContext];
    }];
}


#pragma mark - Private methods

- (TracksEventCoreData *)findTracksEventCoreDataWithUUID:(NSUUID *)uuid
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"TracksEvent"];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", [uuid UUIDString]];
    fetchRequest.predicate = predicate;
    
    NSError *error;
    NSArray *results = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if (error) {
        NSLog(@"Error while fetching TracksEvent by UUID: %@", error);
        return nil;
    }
    
    return results.firstObject;
}

- (TracksEventCoreData *)createTracksEventCoreDataWithTracksEvent:(TracksEvent *)tracksEvent
{
    TracksEventCoreData *tracksEventCoreData = [NSEntityDescription insertNewObjectForEntityForName:@"TracksEvent" inManagedObjectContext:self.managedObjectContext];
    tracksEventCoreData.uuid = tracksEvent.uuid.UUIDString;
    tracksEventCoreData.eventName = tracksEvent.eventName;
    tracksEventCoreData.date = tracksEvent.date;
    tracksEventCoreData.username = tracksEvent.username;
    tracksEventCoreData.userAgent = tracksEvent.userAgent;
    tracksEventCoreData.userID = tracksEvent.userID;
    tracksEventCoreData.userType = @(tracksEvent.userType);
    tracksEventCoreData.customProperties = tracksEvent.customProperties;
    
    return tracksEventCoreData;
}

- (BOOL)saveManagedObjectContext
{
    NSError *error;
    BOOL result = [self.managedObjectContext save:&error];
    
    if (error) {
        NSLog(@"Error while saving context: %@", error);
    }
    
    return result;
}


- (TracksEvent *)mapToTracksEventWithTracksEventCoreData:(TracksEventCoreData *)tracksEventCoreData
{
    TracksEvent *tracksEvent = [TracksEvent new];
    tracksEvent.uuid = [[NSUUID alloc] initWithUUIDString:tracksEventCoreData.uuid];
    tracksEvent.eventName = tracksEventCoreData.eventName;
    tracksEvent.date = tracksEventCoreData.date;
    tracksEvent.username = tracksEventCoreData.username;
    tracksEvent.userID = tracksEventCoreData.userID;
    tracksEvent.userAgent = tracksEventCoreData.userAgent;
    tracksEvent.userType = tracksEventCoreData.userType.unsignedIntegerValue;
    [tracksEvent.customProperties addEntriesFromDictionary:tracksEventCoreData.customProperties];
    
    return tracksEvent;
}

@end
