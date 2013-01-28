#import "HTTPStringResponse.h"
#import "HTTPLogging.h"

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_OFF; // | HTTP_LOG_FLAG_TRACE;


@implementation HTTPStringResponse

- (id)initWithString:(NSString *)stringParam
{
	if((self = [super init]))
	{
		HTTPLogTrace();
		
		offset = 0;
		string = [stringParam retain];
	}
	return self;
}

- (void)dealloc
{
	HTTPLogTrace();
	
	[string release];
	[super dealloc];
}

- (UInt64)contentLength
{
	UInt64 result = (UInt64)[string length];
	
	HTTPLogTrace2(@"%@[%p]: contentLength - %llu", THIS_FILE, self, result);
	
	return result;
}

- (UInt64)offset
{
	HTTPLogTrace();
	
	return offset;
}

- (void)setOffset:(UInt64)offsetParam
{
	HTTPLogTrace2(@"%@[%p]: setOffset:%llu", THIS_FILE, self, offset);
	
	offset = (NSUInteger)offsetParam;
}

- (NSData *)readDataOfLength:(NSUInteger)lengthParameter
{
	HTTPLogTrace2(@"%@[%p]: readDataOfLength:%lu", THIS_FILE, self, (unsigned long)lengthParameter);
	
	NSUInteger remaining = [string length] - offset;
	NSUInteger length = lengthParameter < remaining ? lengthParameter : remaining;
	
	char *bytes = [string cStringUsingEncoding:NSUTF8StringEncoding] + offset;
	
	offset += length;
	
	return [NSData dataWithBytes:bytes length:length];
}

- (BOOL)isDone
{
	BOOL result = (offset == [string length]);
	
	HTTPLogTrace2(@"%@[%p]: isDone - %@", THIS_FILE, self, (result ? @"YES" : @"NO"));
	
	return result;
}

- (NSDictionary *)httpHeaders
{
	HTTPLogTrace();
	
	return [NSDictionary dictionaryWithObject:@"text/html" forKey:@"Content-type"];
}


@end
