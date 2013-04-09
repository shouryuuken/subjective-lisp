
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <unistd.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#import <libxml/parser.h>

#import "Nu.h"
#import "Misc.h"

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
    static int pthreads_initialized = 0;
    
    if (!pthreads_initialized) {
        if (!event_init_pthreads()) {
            return nil;
        }
        pthreads_initialized = 1;
    }
    
    if (_listener)
        return nil;
    
    
    _base = event_base_new();
    if (!_base) {
        NSLog(@"Could not initialize libevent!");
        return nil;
    }

    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_len = sizeof(sin);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(self.port);
    sin.sin_addr.s_addr = get_wifi_addr();
    NSString *addr = [NSString stringWithFormat:@"%s:%u", inet_ntoa(sin.sin_addr), self.port];
    
    _listener = evconnlistener_new_bind(_base, listener_cb, (void *)self,
                                       LEV_OPT_REUSEABLE|LEV_OPT_CLOSE_ON_FREE, -1,
                                       (struct sockaddr*)&sin,
                                       sizeof(sin));
    
    if (!_listener) {
        NSLog(@"Could not create a listener!");
        event_base_free(_base);
        _base = NULL;
        return nil;
    }
    
    if (pthread_create(&_thread, NULL, nuserver_thread_main, self) != 0) {
        evconnlistener_free(_listener);
        _listener = NULL;
        event_base_free(_base);
        _base = NULL;        
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
    if (self.outputLog.count < 100) {
        [self.outputLog addObject:str];
    } else if (self.outputLog.count == 100) {
        [self.outputLog addObject:@"*** too many items in outputLog ***"];
    }
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data cmd:@""];
}

- (void)prn:(id)obj
{
    NSString *str = [obj description];
    NSLog(@"%@", str);
    str = [NSString stringWithFormat:@"%@\n", str];
    if (self.outputLog.count < 100) {
        [self.outputLog addObject:str];
    } else if (self.outputLog.count == 100) {
        [self.outputLog addObject:@"*** too many items in outputLog ***"];
    }
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

static int
htp_default(evhtp_request_t * req, void * a)
{
    NSString *path = @"/";
    NSMutableDictionary *params = [[[NSMutableDictionary alloc] init] autorelease];
    do {
        evhtp_kv_t * kv;
        for (kv = TAILQ_FIRST(req->headers_in); kv != NULL; kv = TAILQ_NEXT(kv, next)) {
            NSLog(@"< (header) %s=%s", kv->key, kv->val);
        }
    } while(0);
    if (req->uri) {
        if (req->uri->path && req->uri->path->full) {
            path = [NSString stringWithUTF8String:req->uri->path->full];
        }
        if (req->uri->query) {
            evhtp_kv_t * kv;
            for (kv = TAILQ_FIRST(req->uri->query); kv != NULL; kv = TAILQ_NEXT(kv, next)) {
                NSLog(@"< (query) %s=%s", kv->key, kv->val);
                [params setValue:[[NSString stringWithUTF8String:kv->val] urlDecode] forKey:[[NSString stringWithUTF8String:kv->key] urlDecode]];
            }
        }
    }
    NuCell *args = nulist(path, params, nil);
    [[[UIApplication sharedApplication] delegate] performSelectorOnMainThread:@selector(httpHandler:) withObject:nulist(path, params, nil) waitUntilDone:YES];
    id str = [params valueForKey:@"_"];
    id data = [str dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        evbuffer_add(req->buffer_out, [data bytes], [data length]);
    }
    evhtp_headers_add_header(req->headers_out,
                             evhtp_header_new("Content-Type", "text/html", 0, 0));
    return EVHTP_RES_OK;
}

BOOL file_exists(NSString *path)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:path];
}

BOOL valid_docs_subpath(NSString *path)
{
    return [path hasPrefix:[get_docs_path() stringByAppendingString:@"/"]];
}

BOOL valid_docs_path(NSString *path)
{
    if (valid_docs_subpath(path) || [path isEqualToString:get_docs_path()]) {
        return YES;
    }
    return NO;
}

NSString *htp_path_in_docs(evhtp_request_t *req)
{
    return path_in_docs([[NSString stringWithUTF8String:req->uri->path->full] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);
}

static int htp_headget(evhtp_request_t *req, void *a)
{
    NSLog(@"%s %s", (req->method == htp_method_GET) ? "GET" : "HEAD", req->uri->path->full);
    NSString *filePath = htp_path_in_docs(req);
    if (!valid_docs_path(filePath)) {
        NSLog(@"GET %s not valid docs path", [filePath UTF8String]);
        return EVHTP_RES_NOTFOUND;
    }
    struct stat info;
    if (!stat([filePath UTF8String], &info)) {
        if (info.st_mode & S_IFREG) {
            int fd = open([filePath UTF8String], O_RDONLY);
            if (fd < 0) {
                NSLog(@"GET %s unable to open %s", [filePath UTF8String], strerror(errno));
                return EVHTP_RES_NOTFOUND;
            }
            if (info.st_size == 0) {
                close(fd);
                return EVHTP_RES_NOCONTENT;
            }
            evbuffer_add_file(req->buffer_out, fd, 0, info.st_size);
            return EVHTP_RES_OK;
        } else {
            NSLog(@"GET %s not a regular file", [filePath UTF8String]);
            return EVHTP_RES_IAMATEAPOT;
        }
    }
    NSLog(@"GET %s unable to stat file", [filePath UTF8String]);
    return EVHTP_RES_NOTFOUND;
}

static int htp_put_close(evhtp_request_t *req, void *a)
{
    NSLog(@"PUT put_close");
    char *exists_user = (char *)evhtp_kv_find(req->user, "put-exists");
    if (!exists_user) {
        NSLog(@"PUT put_close put-exists not found");
        return EVHTP_RES_OK;
    }
    int exists = (int)strtol(exists_user, NULL, 10);
    char *fd_user = (char *)evhtp_kv_find(req->user, "put-fd");
    if (!fd_user) {
        NSLog(@"PUT put_close put-fd not found");
        return EVHTP_RES_OK;
    }
    int fd = (int)strtol(fd_user, NULL, 10);
    for(;;) {
        int n = evbuffer_write(req->buffer_in, fd);
        NSLog(@"PUT evbuffer_write %d", n);
        if (n < 0) {
            break;
        }
    }
    close(fd);
    req->conn->max_body_size = req->htp->max_body_size;
    int val = (exists) ? EVHTP_RES_OK : EVHTP_RES_CREATED;
    return val;
}

static int htp_put_open(evhtp_request_t *req, void *a)
{
    NSLog(@"PUT %s", req->uri->path->full);
    evhtp_kv_t * kv;
    for (kv = TAILQ_FIRST(req->headers_in); kv != NULL; kv = TAILQ_NEXT(kv, next)) {
        NSLog(@"< %s=%s", kv->key, kv->val);
    }
    
    NSString *filePath = htp_path_in_docs(req);
    if (!valid_docs_path(filePath)) {
        return EVHTP_RES_CONFLICT;
    }
    if (evhtp_header_find(req->headers_in, "Content-Range")) {
        return EVHTP_RES_BADREQ;
    }
    BOOL exists = file_exists(filePath);
    if (exists && is_directory(filePath)) {
        return EVHTP_RES_METHNALLOWED;
    }
    int fd;
    if (exists) {
        fd = open([filePath UTF8String], O_WRONLY|O_TRUNC);
    } else {
        fd = open([filePath UTF8String], O_WRONLY|O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
    }
    if (fd < 0) {
        NSLog(@"PUT unable to open file %s", [filePath UTF8String]);
        return EVHTP_RES_CONFLICT;
    }
    char buf[256];
    snprintf(buf, 256, "%d", fd);
    evhtp_headers_add_header(req->user,
                             evhtp_header_new("put-fd", buf, 0, 1));
    snprintf(buf, 256, "%d", (exists) ? 1 : 0);
    evhtp_headers_add_header(req->user,
                             evhtp_header_new("put-exists", buf, 0, 1));
    req->conn->max_body_size = 0;
    return EVHTP_RES_OK;
}

static int htp_put_write(evhtp_request_t *req, evbuf_t *buf, void *a)
{
    char *fd_user = (char *)evhtp_kv_find(req->user, "put-fd");
    if (!fd_user) {
        NSLog(@"PUT put_write put-fd not found");
        return EVHTP_RES_OK;
    }
    int fd = (int)strtol(fd_user, NULL, 10);
    int n = evbuffer_write(buf, fd);
    return EVHTP_RES_OK;
}

static int htp_delete(evhtp_request_t *req, void *a)
{
    NSLog(@"DELETE %s", req->uri->path->full);
    NSString *filePath = htp_path_in_docs(req);
    if (!valid_docs_subpath(filePath)) {
        NSLog(@"DELETE %s failed", [filePath UTF8String]);
        return EVHTP_RES_CONFLICT;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL exists = file_exists(filePath);
    if (exists) {
        if ([fm removeItemAtPath:filePath error:nil]) {
            NSLog(@"DELETE %s success", [filePath UTF8String]);
            return (exists) ? EVHTP_RES_OK : EVHTP_RES_NOCONTENT;
        }
        NSLog(@"DELETE %s failed", [filePath UTF8String]);
        return EVHTP_RES_CONFLICT;
    }
    NSLog(@"DELETE %s not found", [filePath UTF8String]);
    return EVHTP_RES_NOTFOUND;
}

static int htp_options(evhtp_request_t *req, void *a)
{
    NSLog(@"OPTIONS %s", req->uri->path->full);
    char *user_agent_header = (char *)evhtp_header_find(req->headers_in, "User-Agent");
    char *options_dav = "1, 2";
    if (user_agent_header && !strncmp(user_agent_header, "WebDAVFS/", 9)) {
        options_dav = "1, 2";
    }
    evhtp_headers_add_header(req->headers_out,
                             evhtp_header_new("DAV", options_dav, 0, 0));
    return EVHTP_RES_OK;
}

static int htp_mkcol(evhtp_request_t *req, void *a)
{
    NSLog(@"MKCOL %s", req->uri->path->full);
    NSString *filePath = htp_path_in_docs(req);
    if (!valid_docs_subpath(filePath)) {
        return EVHTP_RES_CONFLICT;
    }
    if (file_exists(filePath)) {
        return EVHTP_RES_METHNALLOWED;
    }
    if (evbuffer_get_length(req->buffer_in) > 0) {
        return EVHTP_RES_UNSUPPORTED;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm createDirectoryAtPath:filePath withIntermediateDirectories:NO attributes:nil error:nil]) {
        return EVHTP_RES_CONFLICT;
    }
    return EVHTP_RES_OK;
}

static int htp_copymove(evhtp_request_t *req, void *a)
{
    NSLog(@"%s %s", (req->method == htp_method_COPY) ? "COPY" : "MOVE", req->uri->path->full);
    BOOL shallow_copy = NO;
    if (req->method == htp_method_COPY) {
        char *depth_header = (char *)evhtp_header_find(req->headers_in, "Depth");
        if (depth_header && (!strcmp(depth_header, "0"))) {
            shallow_copy = YES;
        }
    }
    
    NSString *srcPath = htp_path_in_docs(req);
    if (!file_exists(srcPath)) {
        return EVHTP_RES_PRECONDFAIL;
    }
    char *destination_header = (char *)evhtp_header_find(req->headers_in, "Destination");
    char *host_header = (char *)evhtp_header_find(req->headers_in, "Host");
    if (!destination_header || !host_header) {
        return EVHTP_RES_PRECONDFAIL;
    }
    char *p = strstr(destination_header, host_header);
    if (!p) {
        return EVHTP_RES_PRECONDFAIL;
    }
    p += strlen(host_header);
    NSString *dstPath = path_in_docs([[NSString stringWithUTF8String:p] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);
    if (!valid_docs_path(dstPath)) {
        return EVHTP_RES_PRECONDFAIL;
    }
    
    if (!is_directory([dstPath stringByDeletingLastPathComponent])) {
        return EVHTP_RES_CONFLICT;
    }
    BOOL dst_exists = file_exists(dstPath);
    if (dst_exists) {
        char *overwrite_header = (char *)evhtp_header_find(req->headers_in, "Overwrite");
        if (overwrite_header && !strcmp(overwrite_header, "F")) {
            return EVHTP_RES_PRECONDFAIL;
        }
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    if (dst_exists) {
        if (![fm removeItemAtPath:dstPath error:nil]) {
            return EVHTP_RES_CONFLICT;
        }
    }
    
    BOOL val = NO;
    if (req->method == htp_method_COPY) {
        if (shallow_copy && is_directory(srcPath)) {
            val = [fm createDirectoryAtPath:dstPath withIntermediateDirectories:NO attributes:nil error:nil];
        } else {
            val = [fm copyItemAtPath:srcPath toPath:dstPath error:nil];
        }
    } else {
        val = [fm moveItemAtPath:srcPath toPath:dstPath error:nil];
    }
    if (!val) {
        return EVHTP_RES_CONFLICT;
    }
    return (dst_exists) ? EVHTP_RES_NOCONTENT : EVHTP_RES_CREATED;
}

#define DAVXML_PARSE_OPTIONS (XML_PARSE_NONET | XML_PARSE_RECOVER | XML_PARSE_NOBLANKS | XML_PARSE_COMPACT | XML_PARSE_NOWARNING | XML_PARSE_NOERROR)

#define DAVPROP_RESOURCE_TYPE 0x00000001
#define DAVPROP_CREATION_DATE 0x00000002
#define DAVPROP_LAST_MODIFIED 0x00000004
#define DAVPROP_CONTENT_LENGTH 0x00000008
#define DAVPROP_ALL 0x0000000f

static xmlNodePtr find_xml_node(xmlNodePtr node, char *name) {
    while (node) {
        if ((node->type == XML_ELEMENT_NODE) && !xmlStrcmp(node->name, (const xmlChar *)name)) {
            return node;
        }
        node = node->next;
    }
    return NULL;
}

static NSString *gen_propfind_xml(NSString *itemPath, NSString *resourcePath, uint32_t properties)
{
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    
    CFStringRef escapedPath = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)resourcePath, NULL,
                                                                      CFSTR("<&>?+"), kCFStringEncodingUTF8);
    if (escapedPath) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:itemPath error:nil];
        BOOL isDirectory = [[attrs fileType] isEqualToString:NSFileTypeDirectory];
        [arr addObject:@"<D:response>"];
        [arr addObject:@"<D:href>"];
        [arr addObject:escapedPath];
        [arr addObject:@"</D:href>"];
        [arr addObject:@"<D:propstat>"];
        [arr addObject:@"<D:prop>"];
        
        if (properties & DAVPROP_RESOURCE_TYPE) {
            if (isDirectory) {
                [arr addObject:@"<D:resourcetype><D:collection/></D:resourcetype>"];
            } else {
                [arr addObject:@"<D:resourcetype/>"];
            }
        }
        
        if ((properties & DAVPROP_CREATION_DATE) && [attrs objectForKey:NSFileCreationDate]) {
            NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
            formatter.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];
            formatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'+00:00'";
            [arr addObject:@"<D:creationdate>"];
            [arr addObject:[formatter stringFromDate:[attrs fileCreationDate]]];
            [arr addObject:@"</D:creationdate>"];
        }
        
        if ((properties & DAVPROP_LAST_MODIFIED) && [attrs objectForKey:NSFileModificationDate]) {
            NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
            formatter.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];
            formatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
            formatter.dateFormat = @"EEE', 'd' 'MMM' 'yyyy' 'HH:mm:ss' GMT'";
            [arr addObject:@"<D:getlastmodified>"];
            [arr addObject:[formatter stringFromDate:[attrs fileModificationDate]]];
            [arr addObject:@"</D:getlastmodified>"];
        }
        
        if ((properties & DAVPROP_CONTENT_LENGTH) && !isDirectory && [attrs objectForKey:NSFileSize]) {
            [arr addObject:[NSString stringWithFormat:@"<D:getcontentlength>%qu</D:getcontentlength>", [attrs fileSize]]];
        }
        
        [arr addObject:@"</D:prop>"];
        [arr addObject:@"<D:status>HTTP/1.1 200 OK</D:status>"];
        [arr addObject:@"</D:propstat>"];
        [arr addObject:@"</D:response>\n"];
        CFRelease(escapedPath);
    }
    return [arr componentsJoinedByString:@""];
}

static BOOL parse_propfind_xml(NSData *body, uint32_t *properties)
{
    BOOL success = YES;
    *properties = 0;
    xmlDocPtr document = xmlReadMemory(body.bytes, (int)body.length, NULL, NULL, DAVXML_PARSE_OPTIONS);
    if (document) {
        xmlNodePtr node = find_xml_node(document->children, "propfind");
        if (node) {
            node = find_xml_node(node->children, "prop");
        }
        if (node) {
            node = node->children;
            while (node) {
                if (!node->ns) {
                    success = NO;
                    break;
                }
                if (!xmlStrcmp(node->name, (const xmlChar *)"resourcetype")) {
                    *properties |= DAVPROP_RESOURCE_TYPE;
                } else if (!xmlStrcmp(node->name, (const xmlChar *)"creationdate")) {
                    *properties |= DAVPROP_CREATION_DATE;
                } else if (!xmlStrcmp(node->name, (const xmlChar *)"getlastmodified")) {
                    *properties |= DAVPROP_LAST_MODIFIED;
                } else if (!xmlStrcmp(node->name, (const xmlChar *)"getcontentlength")) {
                    *properties |= DAVPROP_CONTENT_LENGTH;
                } else {
                    NSLog(@"PROPFIND Unknown DAV property requested '%s'", node->name);
                }
                node = node->next;
            }
        } else {
            NSLog(@"PROPFIND Invalid DAV properties");
            success = NO;
        }
        xmlFreeDoc(document);
    } else {
        NSLog(@"PROPFIND Unable to parse xml");
        success = NO;
    }
    if (success && !*properties) {
        *properties = DAVPROP_ALL;
    }
    return success;
}

static int htp_propfind(evhtp_request_t *req, void *a)
{
    NSLog(@"PROPFIND %s", req->uri->path->full);
    char *depth_header = (char *)evhtp_header_find(req->headers_in, "Depth");
    if (!depth_header) {
        return EVHTP_RES_FORBIDDEN;
    }
    int depth;
    if (!strcmp(depth_header, "0")) {
        depth = 0;
    } else if (!strcmp(depth_header, "1")) {
        depth = 1;
    } else {
        return EVHTP_RES_FORBIDDEN;
    }
    
    int len = evbuffer_get_length(req->buffer_in);
    NSData *body = [NSMutableData dataWithLength:len];
    evbuffer_remove(req->buffer_in, [body bytes], len);
    
    uint32_t properties = 0;
    if (!parse_propfind_xml(body, &properties)) {
        return EVHTP_RES_BADREQ;
    }
    
    NSString *resourcePath = [NSString stringWithUTF8String:req->uri->path->full];
    NSString *basePath = htp_path_in_docs(req);
    if (!valid_docs_path(basePath) || !file_exists(basePath)) {
        return EVHTP_RES_NOTFOUND;
    }
    
    NSMutableArray *xmlResponse = [[[NSMutableArray alloc] init] autorelease];
    [xmlResponse addObject:@"<?xml version=\"1.0\" encoding=\"utf-8\" ?>"];
    [xmlResponse addObject:@"<D:multistatus xmlns:D=\"DAV:\">\n"];
    if (![resourcePath hasPrefix:@"/"]) {
        resourcePath = [@"/" stringByAppendingString:resourcePath];
    }
    [xmlResponse addObject:gen_propfind_xml(basePath, resourcePath, properties)];
    if (depth == 1) {
        if (![resourcePath hasSuffix:@"/"]) {
            resourcePath = [resourcePath stringByAppendingString:@"/"];
        }
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:basePath];
        NSString *path;
        while ((path = [enumerator nextObject])) {
            [xmlResponse addObject:gen_propfind_xml([basePath stringByAppendingPathComponent:path], [resourcePath stringByAppendingString:path], properties)];
            [enumerator skipDescendents];
        }
    }
    [xmlResponse addObject:@"</D:multistatus>"];
    
    evhtp_headers_add_header(req->headers_out,
                             evhtp_header_new("Content-Type", "application/xml; charset=\"utf-8\"", 0, 0));
    NSString *xmlString = [xmlResponse componentsJoinedByString:@""];
    NSData *data = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
    evbuffer_add(req->buffer_out, [data bytes], [data length]);
    return EVHTP_RES_MSTATUS;
}

static int htp_lock(evhtp_request_t *req, void *a)
{
    NSLog(@"LOCK %s", req->uri->path->full);
    NSString *path = htp_path_in_docs(req);
    if (!valid_docs_path(path)) {
        return EVHTP_RES_FORBIDDEN;
    }
    
    char *if_header = (char *)evhtp_header_find(req->headers_in, "If");
    NSMutableString *lock_token = nil;
    if (if_header) {
        lock_token = [NSMutableString stringWithUTF8String:if_header];
        if ([lock_token hasPrefix:@"(<"]) {
            [lock_token replaceCharactersInRange:NSMakeRange(0, 2) withString:@""];
        }
        if ([lock_token hasSuffix:@">)"]) {
            [lock_token replaceCharactersInRange:NSMakeRange([lock_token length]-2, 2) withString:@""];
        }
    }
    char *depth_header = (char *)evhtp_header_find(req->headers_in, "Depth");
    NSString* depth = (depth_header) ? [NSString stringWithUTF8String:depth_header] : nil; //@"0";
    NSString* scope = nil; //@"exclusive";
    NSString* type = nil; //@"write";
    NSString* owner = nil;
    
    int len = evbuffer_get_length(req->buffer_in);
    NSData *body = [NSMutableData dataWithLength:len];
    evbuffer_remove(req->buffer_in, [body bytes], len);
    
    xmlDocPtr document = xmlReadMemory(body.bytes, (int)body.length, NULL, NULL, DAVXML_PARSE_OPTIONS);
    if (document) {
        xmlNodePtr node = find_xml_node(document->children, "lockinfo");
        if (node) {
            xmlNodePtr scopeNode = find_xml_node(node->children, "lockscope");
            if (scopeNode && scopeNode->children && scopeNode->children->name) {
                scope = [NSString stringWithUTF8String:(char *)scopeNode->children->name];
            }
            xmlNodePtr typeNode = find_xml_node(node->children, "locktype");
            if (typeNode && typeNode->children && typeNode->children->name) {
                type = [NSString stringWithUTF8String:(char *)typeNode->children->name];
            }
            xmlNodePtr ownerNode = find_xml_node(node->children, "owner");
            if (ownerNode) {
                ownerNode = find_xml_node(ownerNode->children, "href");
                if (ownerNode && ownerNode->children && ownerNode->children->content) {
                    owner = [NSString stringWithUTF8String:(char *)ownerNode->children->content];
                }
            }
        } else {
            NSLog(@"LOCK Invalid DAV properties");
        }
        xmlFreeDoc(document);
    }
    BOOL path_exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (path_exists || [[NSData data] writeToFile:path atomically:YES]) {
        char *timeout_header = (char *)evhtp_header_find(req->headers_in, "Timeout");
        
        NSString* token;
        if (lock_token) {
            token = lock_token;
        } else {
            CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
            token = [NSString stringWithFormat:@"urn:uuid:%@", [(id)CFUUIDCreateString(kCFAllocatorDefault, uuid) autorelease]];
            CFRelease(uuid);
        }
        
        NSMutableArray *xmlResponse = [[[NSMutableArray alloc] init] autorelease];
        [xmlResponse addObject:@"<?xml version=\"1.0\" encoding=\"utf-8\" ?>"];
        [xmlResponse addObject:@"<D:prop xmlns:D=\"DAV:\">\n"];
        [xmlResponse addObject:@"<D:lockdiscovery>\n<D:activelock>\n"];
        if (type)
            [xmlResponse addObject:[NSString stringWithFormat:@"<D:locktype><D:%@/></D:locktype>\n", type]];
        if (scope)
            [xmlResponse addObject:[NSString stringWithFormat:@"<D:lockscope><D:%@/></D:lockscope>\n", scope]];
        if (depth)
            [xmlResponse addObject:[NSString stringWithFormat:@"<D:depth>%@</D:depth>\n", depth]];
        if (owner) {
            [xmlResponse addObject:[NSString stringWithFormat:@"<D:owner><D:href>%@</D:href></D:owner>\n", owner]];
        }
        if (timeout_header) {
            [xmlResponse addObject:[NSString stringWithFormat:@"<D:timeout>%s</D:timeout>\n", timeout_header]];
        }
        [xmlResponse addObject:[NSString stringWithFormat:@"<D:locktoken><D:href>%@</D:href></D:locktoken>\n", token]];
        [xmlResponse addObject:@"</D:activelock>\n</D:lockdiscovery>\n"];
        [xmlResponse addObject:@"</D:prop>"];
        
        evhtp_headers_add_header(req->headers_out,
                                 evhtp_header_new("Content-Type", "application/xml; charset=\"utf-8\"", 0, 0));
        evhtp_headers_add_header(req->headers_out,
                                 evhtp_header_new("Lock-Token", [token UTF8String], 0, 0));
        
        NSString *xmlString = [xmlResponse componentsJoinedByString:@""];
        NSData *data = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
        evbuffer_add(req->buffer_out, [data bytes], [data length]);
        return (path_exists) ? EVHTP_RES_OK : EVHTP_RES_CREATED;
    }
    
    return EVHTP_RES_FORBIDDEN;
}

static int htp_unlock(evhtp_request_t *req, void *a)
{
    NSLog(@"UNLOCK %s", req->uri->path->full);
    char *token_header = (char *)evhtp_header_find(req->headers_in, "Lock-Token");
    return (token_header) ? EVHTP_RES_NOCONTENT : EVHTP_RES_BADREQ;
}

static int htp_dispatch(evhtp_request_t *req, void *a)
{
    if ((req->method == htp_method_HEAD) || (req->method == htp_method_GET)) {
        int val = htp_headget(req, a);
        if (val == EVHTP_RES_IAMATEAPOT)
            return htp_default(req, a);
        return val;
    }
    
    if (req->method == htp_method_POST)
        return htp_default(req, a);
    
    if (req->method == htp_method_PUT)
        return htp_put_close(req, a);
    
    if (req->method == htp_method_DELETE)
        return htp_delete(req, a);
    
    if (req->method == htp_method_OPTIONS)
        return htp_options(req, a);
    
    if (req->method == htp_method_MKCOL)
        return htp_mkcol(req, a);
    
    if ((req->method == htp_method_COPY) || (req->method == htp_method_MOVE))
        return htp_copymove(req, a);
    
    if (req->method == htp_method_PROPFIND)
        return htp_propfind(req, a);
    
    if (req->method == htp_method_LOCK)
        return htp_lock(req, a);
    
    if (req->method == htp_method_UNLOCK)
        return htp_unlock(req, a);
    
    return EVHTP_RES_IAMATEAPOT;
}

static evhtp_res htp_hook_on_read(evhtp_request_t *req, evbuf_t *buf, void *a)
{
    NSLog(@"htp_hook_on_read");
    if (req->method == htp_method_PUT)
        return htp_put_write(req, buf, a);
    return EVHTP_RES_OK;
}

static evhtp_res htp_hook_on_headers(evhtp_request_t *req, evhtp_headers_t *hdr, void *a)
{
    NSLog(@"htp_hook_on_headers");
    if (req->method == htp_method_PUT)
        return htp_put_open(req, a);
    return EVHTP_RES_OK;
}

static evhtp_res htp_pre_accept_cb(evhtp_connection_t *conn, void *a)
{
    NSLog(@"htp_pre_accept_cb");
    evhtp_set_hook(&conn->hooks, evhtp_hook_on_headers, htp_hook_on_headers, NULL);
    evhtp_set_hook(&conn->hooks, evhtp_hook_on_read, htp_hook_on_read, NULL);
    return EVHTP_RES_OK;
}

static void htp_gencb(evhtp_request_t *req, void *a)
{
    NSLog(@"htp_gencb");
    evhtp_send_reply(req, htp_dispatch(req, NULL));
}

@interface WebServer : NSObject
{
    pthread_t _thread;
    struct event_base *_base;
    evhtp_t *_htp;
}
- (NSString *)start;
- (void)stop;
@property (nonatomic, assign) int port;
@property (nonatomic, assign) int maximumBodySize;
@end

@implementation WebServer
@synthesize port = _port;
@synthesize maximumBodySize = _maximumBodySize;

- (void)dealloc
{
    [self stop];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) {
        self.port = 80;
        self.maximumBodySize = 4096;
    }
    return self;
}

static void *webserver_thread_main(void *ptr)
{
    @autoreleasepool {
        WebServer *server = ptr;
        NSLog(@"webserver_thread_main started");
        event_base_dispatch(server->_base);
        NSLog(@"webserver_thread_main finished");
    }
    return NULL;
}

- (void)stop
{
    if (_htp) {
        struct timeval delay = { 0, 0 };
        event_base_loopexit(_base, &delay);
        pthread_join(_thread, NULL);
        NSLog(@"webserver_thread_main cleaning up");
        evhtp_unbind_socket(_htp);
        evhtp_free(_htp);
        _htp = NULL;
        event_base_free(_base);
        _base = NULL;
        NSLog(@"web server stopped");
    }
}

- (NSString *)start
{
    NSString *addr = get_wifi_ntoa();
    
    if (_htp) {
        NSLog(@"web server already running");
        return nil;
    }
    
    NSLog(@"starting web server");
    
    if (!event_init_pthreads()) {
        return nil;
    }
    
    _base = event_base_new();
    if (!_base) {
        NSLog(@"Could not initialize libevent!");
        return nil;
    }
    
    _htp = evhtp_new(_base, NULL);
    if (!_htp) {
        NSLog(@"Could not initialize libevhtp!");
        return nil;
    }
    
    evhtp_set_max_body_size(_htp, self.maximumBodySize);
    evhtp_set_pre_accept_cb(_htp, htp_pre_accept_cb, NULL);
    evhtp_set_gencb(_htp, htp_gencb, NULL);
    
    evhtp_bind_socket(_htp, [addr UTF8String], self.port, 1024);
    
    if (pthread_create(&_thread, NULL, webserver_thread_main, self) != 0) {
        return nil;
    }
    
    return addr;
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

@interface AppDelegate : UIViewController <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) NSUbiquitousKeyValueStore *kvStore;
@property (nonatomic, retain) NSOperationQueue *taskQueue;
@property (nonatomic, retain) NuServer *nuServer;
@property (nonatomic, retain) WebServer *webServer;
@property (nonatomic, retain) NSMutableDictionary *symbols;
@end

@implementation AppDelegate
@synthesize window = _window;
@synthesize kvStore = _kvStore;
@synthesize taskQueue = _taskQueue;
@synthesize nuServer = _nuServer;
@synthesize webServer = _webServer;
@synthesize symbols = _symbols;


- (void)main:(id)obj
{
    NSLog(@"AppDelegate main:");
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    self.window.backgroundColor = [UIColor blackColor];
    
    self.taskQueue = [[[NSOperationQueue alloc] init] autorelease];
    [self.taskQueue setMaxConcurrentOperationCount:1];
    NSString *icloud_kvs_path = nu_to_string(@"icloud-kvs-path");
    if (icloud_kvs_path) {
        NSLog(@"icloud-kvs enabled '%@'", icloud_kvs_path);
        self.kvStore = [NSUbiquitousKeyValueStore defaultStore];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kvStoreDidChange:) name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:nil];
        [self.kvStore synchronize];
    }
    if (nu_objectIsKindOfClass(obj, [NuBlock class])) {
        obj = execute_block_safely(^{ return [obj evalWithArguments:nil]; });
    }
    if (nu_objectIsKindOfClass(obj, [UIViewController class])) {
        self.window.rootViewController = obj;
    }
    [self.window makeKeyAndVisible];
    //    [[GameKitHelper sharedGameKitHelper] authenticateLocalPlayer];
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
        if (!self.webServer) {
            self.webServer = [[[WebServer alloc] init] autorelease];
        }
        NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
        NSString *addr;
        
        addr = [self.nuServer start];
        if (addr) {
            [arr addObject:[NSString stringWithFormat:@"nu %@", addr]];
        }
        
        addr = [self.webServer start];
        if (addr) {
            [arr addObject:[NSString stringWithFormat:@"http %@", addr]];
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
        [self.webServer stop];
    }
}

- (void)httpHandler:(id)args
{
    NSLog(@"httpHandler '%@'", args);
    id str = eval_function_core(@"html-document", args);
    NSMutableDictionary *params = [args cadr];
    [params setValue:str forKey:@"_"];
}

@end

@interface DefaultAppDelegate : AppDelegate
@end

@implementation DefaultAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UIViewController *vc = [[[UIViewController alloc] init] autorelease];
    [self main:vc];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self stopServers];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self startServers];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self startServers];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [self stopServers];
}


@end

@interface Main : NSObject
@end

@implementation Main

+ (id)allocWithZone:(NSZone *)zone
{
    static id global = nil;
    if (!global) {
        [[NuSymbolTable sharedSymbolTable] loadSymbols];
        id name = get_symbol_value(@"initial-symbol");
        if (nu_objectIsKindOfClass(name, [NSString class])) {
            NSLog(@"looking for initial-symbol '%@' to be app delegate", name);
            global = get_symbol_value(name);
            if (!global) {
                NSLog(@"symbol not found for initial-symbol '%@', using DefaultAppDelegate", name);
            }
        } else {
            NSLog(@"initial-symbol not specified, using DefaultAppDelegate");
        }
        if (!global) {
            global = [[DefaultAppDelegate alloc] init];
        }
    }
    
    return global;
}

- (id)init
{
    NSLog(@"Main init");
    return [super init];
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;
}

@end

