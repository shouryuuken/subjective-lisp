#import <Foundation/Foundation.h>
#import "HTTPResponse.h"


@interface HTTPStringResponse : NSObject <HTTPResponse>
{
	NSUInteger offset;
	NSString *string;
}

- (id)initWithString:(NSString *)string;

@end
