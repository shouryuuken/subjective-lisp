
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <unistd.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#import <libxml/parser.h>

#import "Nu.h"
#import "Misc.h"

#import "HTTPServer.h"
#import "DAVConnection.h"

#import "GameKitGlue.h"

uint32_t get_wifi_addr()
{
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    uint32_t in_addr = htonl(INADDR_ANY);
    
    if (getifaddrs(&interfaces) == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                NSString *ifname = [NSString stringWithUTF8String:temp_addr->ifa_name];
                if([ifname isEqualToString:@"bridge0"] || [ifname isEqualToString:@"en0"]) {
                    in_addr = ((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr.s_addr;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return in_addr;
}

NSString *get_wifi_ntoa()
{
    struct in_addr in;
    memset(&in, 0, sizeof(in));
    in.s_addr = get_wifi_addr();
    return [NSString stringWithUTF8String:inet_ntoa(in)];
}

static int event_init_pthreads()
{
    static int is_initialized = 0;
    
    if (is_initialized) {
        return 1;
    }
    
    if (evthread_use_pthreads() != 0) {
        NSLog(@"Could not initialize pthreads for libevent!");
        return 0;
    }
    
    is_initialized = 1;
    return 1;
}


@implementation NuServer
@synthesize inputBuffer = _inputBuffer;
@synthesize needBytes = _needBytes;
@synthesize bytesHandler = _bytesHandler;
@synthesize commandName = _commandName;

@synthesize port = _port;
@synthesize outputLog = _outputLog;

- (void)dealloc
{
    [self stop];
    self.inputBuffer = nil;
    self.outputLog = nil;
    self.commandName = nil;
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) {
        self.inputBuffer = [[[NSMutableData alloc] init] autorelease];
        self.port = 6502;
        self.outputLog = [[[NSMutableArray alloc] init] autorelease];
    }
    return self;
}

- (void)endClient
{
    if (!self.bytesHandler) {
        if (_bev) {
            bufferevent_write(_bev, "0\r\n\r\n", 5);
        }
    }
    _bev = NULL;
    [self.inputBuffer setLength:0];
    self.commandName = nil;
}

- (void)newClient:(id)obj
{
    [self endClient];
    [[Nu sharedParser] reset];
    [self.inputBuffer setLength:0];
    self.commandName = nil;
    self.needBytes = 4;
    self.bytesHandler = @selector(parseMagic);
    _bev = [(NSValue *)obj pointerValue];
}

- (void)handleBytes
{
    while (self.bytesHandler && ([self.inputBuffer length] >= self.needBytes)) {
        [self performSelector:self.bytesHandler withObject:nil];
     }
    if (!self.bytesHandler) {
        [self.inputBuffer setLength:0];
    }
}

static void
conn_readcb(struct bufferevent *bev, void *user_data)
{
    NuServer *server = user_data;
    size_t len;
    char buf[4096];
    for(;;) {
        len = bufferevent_read(bev, buf, 4096);
        if (len <= 0)
            break;
        [server->_inputBuffer appendBytes:buf length:len];
    }
    [server performSelectorOnMainThread:@selector(handleBytes) withObject:nil waitUntilDone:YES];
}

static void
conn_writecb(struct bufferevent *bev, void *user_data)
{
}

static void
conn_eventcb(struct bufferevent *bev, short events, void *user_data)
{
    NuServer *server = user_data;
    if (events & BEV_EVENT_EOF) {
        printf("Connection closed.\n");
    } else if (events & BEV_EVENT_ERROR) {
        printf("Got an error on the connection: %s\n",
               strerror(errno));/*XXX win32*/
    }
    /* None of the other events can happen here, since we haven't enabled
     * timeouts */
    [server performSelectorOnMainThread:@selector(endClient) withObject:nil waitUntilDone:YES];
    bufferevent_free(bev);
}

static void
listener_cb(struct evconnlistener *listener, evutil_socket_t fd,
            struct sockaddr *sa, int socklen, void *user_data)
{
    NuServer *server = user_data;
    struct event_base *base = server->_base;
    struct bufferevent *bev;
    
    bev = bufferevent_socket_new(base, fd, BEV_OPT_CLOSE_ON_FREE);
    if (!bev) {
        NSLog(@"Error constructing bufferevent!");
        event_base_loopbreak(base);
        return;
    }
    
    [server performSelectorOnMainThread:@selector(newClient:) withObject:[NSValue valueWithPointer:bev] waitUntilDone:YES];
    bufferevent_setcb(bev, conn_readcb, conn_writecb, conn_eventcb, server);
    bufferevent_enable(bev, EV_WRITE);
    bufferevent_enable(bev, EV_READ);
    
}

static void *nuserver_thread_main(void *ptr)
{
    @autoreleasepool {
        NuServer *server = ptr;
        NSLog(@"nuserver_thread_main started");
        event_base_dispatch(server->_base);
        NSLog(@"nuserver_thread_main finished");
    }
    return NULL;
}

- (void)stop
{
    if (!_listener)
        return;
    
    [self endClient];
    
    struct timeval delay = { 0, 0 };
    event_base_loopexit(_base, &delay);
    pthread_join(_thread, NULL);
    
    evconnlistener_free(_listener);
    _listener = NULL;
    event_base_free(_base);
    _base = NULL;
}

- (NSString *)start
{
    NSLog(@"starting nu server");
    
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_len = sizeof(sin);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(self.port);
    sin.sin_addr.s_addr = get_wifi_addr();
    NSString *addr = [NSString stringWithFormat:@"%s:%u", inet_ntoa(sin.sin_addr), self.port];

    if (_listener)
        return nil;
    
    if (!event_init_pthreads()) {
        return nil;
    }
    
    _base = event_base_new();
    if (!_base) {
        NSLog(@"Could not initialize libevent!");
        return nil;
    }

    _listener = evconnlistener_new_bind(_base, listener_cb, (void *)self,
                                       LEV_OPT_REUSEABLE|LEV_OPT_CLOSE_ON_FREE, -1,
                                       (struct sockaddr*)&sin,
                                       sizeof(sin));
    
    if (!_listener) {
        NSLog(@"Could not create a listener!");
        return nil;
    }
    
    if (pthread_create(&_thread, NULL, nuserver_thread_main, self) != 0) {
        return nil;
    }
   
    return addr;
}

- (void)sendData:(NSData *)data cmd:(NSString *)cmd
{
    @synchronized (self) {
        if (!_bev)
            return;
        
        if (self.bytesHandler) {
            char buf[513];
            sprintf(buf, "%-256.256s%-256.256s",
                             [[NSString stringWithFormat:@"%d", [data length]]
                              UTF8String],
                             [cmd UTF8String]);
            bufferevent_write(_bev, buf, 512);
            if ([data length] > 0) {
                bufferevent_write(_bev, [data bytes], [data length]);
            }
        } else {
            [self writeChunked:[[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease]];
        }
    }
}

- (BOOL)sendFile:(NSString *)path
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data)
        return NO;
    [self sendData:data cmd:[path lastPathComponent]];
    return YES;
}

- (void)pr:(id)obj
{
    NSString *str = [obj description];
    NSLog(@"%@", str);
    [self.outputLog addObject:str];
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data cmd:@""];
}

- (void)prn:(id)obj
{
    NSString *str = [obj description];
    NSLog(@"%@", str);
    str = [NSString stringWithFormat:@"%@\n", str];
    [self.outputLog addObject:str];
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data cmd:@""];
}

- (NSString *)readlog
{
    if (!self.outputLog.count) {
        return nil;
    }
    NSString *str = [self.outputLog componentsJoinedByString:@""];
    [self.outputLog removeAllObjects];
    return str;    
}

- (void)writeChunked:(NSString *)str
{
    if (!str)
        return;
    if (![str length])
        return;
    if (!_bev)
        return;
    char *bytes = [str UTF8String];
    char buf[256];
    snprintf(buf, 256, "%x\r\n", strlen(bytes));
    bufferevent_write(_bev, buf, strlen(buf));
    bufferevent_write(_bev, bytes, strlen(bytes));
    bufferevent_write(_bev, "\r\n", 2);
}

- (void)parseMagic
{
    uint8_t *bytes = [self.inputBuffer mutableBytes];
    if (!strncmp(bytes, "#!nu", 4)) {
        NSLog(@"parsed magic");
        [self.inputBuffer replaceBytesInRange:NSMakeRange(0, 4) withBytes:NULL length:0];
        self.commandName = nil;
        self.needBytes = 512;
        self.bytesHandler = @selector(parseHeader);
    } else {
        NSLog(@"no magic found");
        [self.inputBuffer setLength:0];
        self.commandName = nil;
        self.needBytes = 512;
        self.bytesHandler = nil;
        if (_bev) {
            char *str = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-type: text/plain\r\n\r\n";
            bufferevent_write(_bev, str, strlen(str));
            [self writeChunked:[NSString stringWithFormat:@"%1024s\n", ""]];
            [self writeChunked:[self readlog]];
        }
    }
}

- (void)parseHeader
{
    NSString *(^trim)(NSString *str) = ^(NSString *str) {
        return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    };
    uint8_t *bytes = [self.inputBuffer mutableBytes];
    self.needBytes = [[NSString stringWithFormat:@"%.10s", &bytes[0]] intValue];
    if (self.needBytes < 0) {
        NSLog(@"die");
        exit(0);
    }
    self.commandName = [trim([NSString stringWithFormat:@"%.256s", &bytes[256]]) retain];
    [self.inputBuffer replaceBytesInRange:NSMakeRange(0, 512) withBytes:NULL length:0];
    NSLog(@"parsed header: command '%@' size '%d'", self.commandName, self.needBytes);
    self.bytesHandler = @selector(handleCommand);
}

- (void)handleCommand
{
    if (self.needBytes > 0) {
        NSData *bytes = [NSData dataWithBytesNoCopy:[self.inputBuffer mutableBytes] length:self.needBytes freeWhenDone:NO];
        if ([self.commandName length]) {
            [self prn:[NSString stringWithFormat:@"*** fn '%@' %d", self.commandName, self.needBytes]];
            
            id block = [self.commandName parseEval];
            id result = eval_block(block, bytes, nil);
            [self prn:[result description]];
            
        } else {
            NSString *str = [[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] autorelease];
            [self prn:[NSString stringWithFormat:@"*** parse '%@'", str]];
            id result = [str parseEval];
            [self prn:[result description]];
        }
        [self.inputBuffer replaceBytesInRange:NSMakeRange(0, self.needBytes) withBytes:NULL length:0];
    }
    [self.commandName release];
    self.commandName = nil;
    self.needBytes = 512;
    self.bytesHandler = @selector(parseHeader);
    [[Nu sharedParser] reset];
}

@end



@interface GlueTask : NSOperation
@property (nonatomic, retain) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, retain) id object;
@end


@implementation GlueTask

@synthesize target = _target;
@synthesize action = _action;
@synthesize object = _object;

- (void)dealloc
{
    self.target = nil;
    self.action = nil;
    self.object = nil;
    [super dealloc];
}

- (id)initWithTarget:(id)target action:(SEL)action object:(id)object
{
    self = [super init];
    if (self) {
        self.target = target;
        self.action = action;
        self.object = object;
    }
    return self;
}

- (void)main
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (![self isCancelled]) {
        [NSClassFromString(self.target) performSelector:self.action     withObject:self.object];
    }
    [pool drain];
}

@end



@interface SerialTask : NSOperation
@property (nonatomic, retain) id function;
@property (nonatomic, retain) id args;
@property (nonatomic, assign) BOOL async;
@end


@implementation SerialTask

@synthesize function = _function;
@synthesize args = _args;
@synthesize async = _async;

- (void)dealloc
{
    self.function = nil;
    self.args = nil;
    [super dealloc];
}

- (id)initWithFunction:(id)function args:(id)args async:(BOOL)async
{
    self = [super init];
    if (self) {
        self.function = function;
        self.args = args;
        self.async = async;
    }
    return self;
}

- (void)main
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (![self isCancelled]) {
        if (self.async) {
            [self.function evalWithArguments:self.args];
        } else {
            [self.function performSelectorOnMainThread:@selector(evalWithArguments:) withObject:self.args waitUntilDone:YES];
        }
    }
    [pool drain];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) NSUbiquitousKeyValueStore *kvStore;
@property (nonatomic, retain) NSOperationQueue *taskQueue;
@property (nonatomic, retain) NuServer *nuServer;
@property (nonatomic, retain) HTTPServer *httpServer;
@property (nonatomic, retain) NSMutableDictionary *symbols;
@end

@implementation AppDelegate
@synthesize window = _window;
@synthesize kvStore = _kvStore;
@synthesize taskQueue = _taskQueue;
@synthesize nuServer = _nuServer;
@synthesize httpServer = _httpServer;
@synthesize symbols = _symbols;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.taskQueue = [[[NSOperationQueue alloc] init] autorelease];
    [self.taskQueue setMaxConcurrentOperationCount:1];
    NSString *icloud_kvs_path = nu_to_string(@"icloud-kvs-path");
    if (icloud_kvs_path) {
        NSLog(@"icloud-kvs enabled '%@'", icloud_kvs_path);
        self.kvStore = [NSUbiquitousKeyValueStore defaultStore];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kvStoreDidChange:) name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:nil];
        [self.kvStore synchronize];
    }
    [self startServers];
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    [self.window setBackgroundColor:[UIColor blackColor]];
    [self loadSymbols];
    eval_function(@"application-did-finish-launching", nil);
    [self.window makeKeyAndVisible];
//    [[GameKitHelper sharedGameKitHelper] authenticateLocalPlayer];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    eval_function(@"application-will-resign-active", nil);
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    eval_function(@"application-did-enter-background", nil);
    [self stopServers];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self startServers];
    eval_function(@"application-will-enter-foreground", nil);
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self startServers];
    eval_function(@"application-did-become-active", nil);
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    eval_function(@"application-will-terminate", nil);
    [self stopServers];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    eval_function(@"application-did-receive-memory-warning", nil);
}

- (void)applicationSignificantTimeChange:(UIApplication *)application
{
    eval_function(@"application-significant-time-change", nil);
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    [self startServers];
    eval_function(@"application-open-url", url, sourceApplication, annotation, nil);
    return YES;
}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    eval_function(@"application-motion-began", [NSNumber numberWithInt:motion], event, nil);
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    eval_function(@"application-motion-ended", [NSNumber numberWithInt:motion], event, nil);
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    eval_function(@"application-motion-cancelled", [NSNumber numberWithInt:motion], event, nil);
}

- (void)writeKvStoreKeys:(NSArray *)arr
{
    NSString *path = nu_to_string(@"icloud-kvs-path");
    if (!path)
        return;
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *key in arr) {
        NSString *val = [self.kvStore stringForKey:key];
        NSString *file = [path stringByAppendingPathComponent:key];
        NSString *contents = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
        if (![contents isEqualToString:val]) {
            [val writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        NSLog(@"writeKvStoreKeys key '%@' val '%@'", key, val);
    }
}

- (void)writeKvStoreAllKeys
{
    [self writeKvStoreKeys:self.kvStore.dictionaryRepresentation.allKeys];
}

- (void)kvStoreDidChange:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    int reason = [[userInfo objectForKey:NSUbiquitousKeyValueStoreChangeReasonKey] intValue];
    NSArray *changedKeys = [userInfo objectForKey:NSUbiquitousKeyValueStoreChangedKeysKey];
    [self writeKvStoreKeys:changedKeys];
}

- (void)readKvStorePath
{
    NSString *path = nu_to_string(@"icloud-kvs-path");
    if (!path)
        return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *arr = [fm contentsOfDirectoryAtPath:path error:nil];
    for (NSString *elt in arr) {
        NSString *file = [path stringByAppendingPathComponent:elt];
        NSDictionary *attr = [fm attributesOfItemAtPath:file error:nil];
        if ([attr fileType] == NSFileTypeRegular) {
            NSString *contents = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
            if (![[self.kvStore stringForKey:elt] isEqualToString:contents]) {
                [self.kvStore setString:contents forKey:elt];
            }
        }
    }
    [self.kvStore synchronize];
}

- (void)startServers
{
    if (nu_valueIsTrue(get_symbol_value(@"debug-mode"))) {
        if (!self.nuServer) {
            self.nuServer = [[[NuServer alloc] init] autorelease];
        }
        NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
        NSString *addr;
        
        addr = [self.nuServer start];
        if (addr) {
            [arr addObject:[NSString stringWithFormat:@"nu %@", addr]];
        }
        
        /* CocoaHTTPServer */
        if (!self.httpServer) {
            // Create DAV server
            self.httpServer = [[[HTTPServer alloc] init] autorelease];
            [self.httpServer setConnectionClass:[DAVConnection class]];
            [self.httpServer setPort:80];
            // Enable Bonjour
            [self.httpServer setType:@"_http._tcp."];
            // Set document root
            [self.httpServer setDocumentRoot:get_docs_path()];
        }
        // Start DAV server
        NSError *error = nil;
        if (![self.httpServer start:&error]) {
            NSLog(@"Error starting CocoaHTTPServer: %@", error);
        } else {
            [arr addObject:@"http port 80"];
        }

        if ([arr count]) {
            show_alert(@"Servers", [arr componentsJoinedByString:@"\n"], @"OK");
        }
    }
}

- (void)stopServers
{
    if (nu_valueIsTrue(get_symbol_value(@"debug-mode"))) {
        [self.nuServer stop];
        [self.httpServer stop];
    }
}

- (void)httpHandler:(id)args
{
    NSLog(@"httpHandler '%@'", args);
    id str = eval_function_core(@"html-document", args);
    NSMutableDictionary *params = [args cadr];
    [params setValue:str forKey:@"_"];
}

NSMutableDictionary *all_symbols_to_dict()
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    NSArray *external = [[path_to_symbols() directoriesInDirectory] sort];
    for (id namespace in external) {
        if ([namespace hasPrefix:@"."]) {
            continue;
        }
        NSArray *arr = [path_to_namespace(namespace) directoryContents];
        for (id symbol in arr) {
            NSString *path = path_to_symbol(namespace, symbol);
            if (![path isDirectory]) {
                NSString *str = [path stringFromFile];
                if (!str)
                    str = @"";
                [dict setObject:str forKey:symbol];
            }
        }
    }
    return dict;
}

- (void)loadSymbols
{
    if ([path_to_symbols() isDirectory]) {
        NSLog(@"found symbols directory, not downloading symbols");
        return;
    }
    NSString *url = @"http://interactiveios.org/symbols.json";
    NSLog(@"loading from '%@'", url);
    NuCurl *curl = [[[NuCurl alloc] init] autorelease];
    [curl curlEasySetopt:CURLOPT_URL param:url];
    NSData *result = [curl perform];
    if (result) {
        self.symbols = [result jsonDecode];
        if (self.symbols) {
            NSLog(@"loaded symbols");
            NSLog(@"symbols: %@", self.symbols);
        } else {
            NSLog(@"invalid symbols.json");
        }
    } else {
        NSLog(@"unable to download symbols.json");
    }
}

- (NSMutableDictionary *)symbolsToDictionary
{
    return all_symbols_to_dict();
}

@end


