#import <Foundation/Foundation.h>
#import "TracksEvent.h"

@interface TracksServiceRemote : NSObject

- (void)sendSingleTracksEvent:(TracksEvent *)tracksEvent completionHandler:(void (^)(void))completion;

@end
