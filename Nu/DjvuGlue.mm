//  SoleDjVu
//  http://djvuipad.com/
//
//  Copyright (c) 2012 Arthur Choung. All rights reserved.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//  
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/CALayer.h>

#import "Misc.h"

#include "DjVuImage.h"
#include "DjVuDocument.h"
#include "libdjvu/miniexp.h"
#include "libdjvu/ddjvuapi.h"

#include "DjVmNav.h"
#include "GPixmap.h"
#include "GBitmap.h"

@class NuServer;

static ddjvu_context_t *djvu_ctx = NULL;

int maxint(int a, int b)
{
    if (a > b)
        return a;
    return b;
}

int minint(int a, int b)
{
    if (a < b)
        return a;
    return b;
}

static NSString *getDisplayNameForPath(NSString *path)
{
    return [[path lastPathComponent] stringByDeletingPathExtension];
}

void log_rect(NSString *str, CGRect r)
{
    NSLog(@"%@ %.f %.f %.f %.f", str, r.origin.x, r.origin.y, r.size.width, r.size.height);
}

@class DjvuDocument;
@class Glue;
@class DjvuRenderTask;
@class ZoomingScrollView;

@interface DjvuPageView : UIView
@property (nonatomic, retain) UIActivityIndicatorView *activityView;
@property (nonatomic, assign) CGSize renderSize;
@property (nonatomic, assign) CGSize origSize;
@end

@implementation DjvuPageView
@synthesize renderSize = _renderSize;
@synthesize origSize = _origSize;
@synthesize activityView = _activityView;

- (void)dealloc
{
    self.activityView = nil;
    [super dealloc];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [self layoutSubviews];
        [self addSubview:self.activityView];
    }
    return self;
}

- (void)layoutSubviews
{
    self.activityView.frame = self.bounds;
}

- (void)removeAddedSubviews
{
    NSArray *arr = [self subviews];
    for (UIView *v in arr) {
        if (v == self.activityView) {
            continue;
        }
        [v removeFromSuperview];
    }
}

- (void)highlightSearchResults
{
    [self removeAddedSubviews];
    
    if (!self.origSize.width || !self.origSize.height) {
        NSLog(@"highlightSearchResults: origSize is 0");
        return;
    }
    
    DjvuDocument *document = [[[self superview] superview] document];
    int pageno = ((int)[[self superview] index])+1;
    NSArray *match = nil;
    for (NSArray *elt in [document searchResults]) {
        if ([elt count] != 2)
            continue;
        if (pageno == [[elt objectAtIndex:0] intValue]) {
            match = elt;
            break;
        }
    }
    if (!match)
        return;
    NSArray *arr = [match objectAtIndex:1];
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGFloat xscale=0.0, yscale=0.0, xoff=0.0, yoff=0.0;
    if ([[self superview] zoomScale] > 1.0) {
        CGSize propSize = proportional_size(self.superview.frame.size.width, self.superview.frame.size.height, self.origSize.width, self.origSize.height);
        xscale = propSize.width / self.origSize.width;
        yscale = propSize.height / self.origSize.height;
//        xoff = (self.superview.frame.size.width - propSize.width) / 2.0;
//        yoff = (self.superview.frame.size.height - propSize.height) / 2.0;
    } else {
        xscale = self.renderSize.width / scale / self.origSize.width;
        yscale = self.renderSize.height / scale / self.origSize.height;
        xoff = (self.frame.size.width - (self.renderSize.width / scale)) / 2.0;
        yoff = (self.frame.size.height - (self.renderSize.height / scale)) / 2.0;
        xoff += self.frame.origin.x;
        yoff += self.frame.origin.y;
    }

//    NSLog(@"highlightSearchResults self.frame %.f %.f %.f %.f self.superview.frame %.f %.f %.f %.f renderSize %.f %.f", self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height, self.superview.frame.origin.x, self.superview.frame.origin.y, self.superview.frame.size.width, self.superview.frame.size.height, self.renderSize.width, self.renderSize.height);
    for (NSArray *coords in arr) {
        if ([coords count] != 4)
            continue;
        CGFloat x1 = [[coords objectAtIndex:0] floatValue] * xscale;
        CGFloat y1 = (self.origSize.height - [[coords objectAtIndex:1] floatValue]) * yscale;
        CGFloat x2 = [[coords objectAtIndex:2] floatValue] * xscale;
        CGFloat y2 = (self.origSize.height - [[coords objectAtIndex:3] floatValue]) * yscale;
//        NSLog(@"origSize %f %f", self.origSize.width, self.origSize.height);
//        NSLog(@"xscale %f yscale %f", xscale, yscale);
//        NSLog(@"coords %f %f %f %f", [[coords objectAtIndex:0] floatValue], [[coords objectAtIndex:1] floatValue], [[coords objectAtIndex:2] floatValue], [[coords objectAtIndex:3] floatValue]);
//        NSLog(@"highlightSearchResults xoff %.f yoff %.f x1 %.f y1 %.f x2 %.f y2 %.f w %.f h %.f", xoff, yoff, x1, y1, x2, y2, fabs(x2-x1), fabs(y2-y1));
        UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(xoff+x1, yoff+y2, fabs(x2-x1), fabs(y2-y1))] autorelease];
        v.alpha = 0.5;
        v.backgroundColor = [UIColor colorWithRed:0.80 green:0.80 blue:0.0 alpha:1.0];
        v.layer.cornerRadius = 5;
        v.layer.borderWidth = 1;
        v.layer.borderColor = [[UIColor yellowColor] CGColor];
        [self addSubview:v];
//        NSLog(@"highlightSearchResults: pageno %d xoff %.f yoff %.f x1 %.f y1 %.f x2 %.f y2 %.f", pageno, xoff, yoff, x1, y1, x2, y2);
    }
}


@end




@interface PixelBuffer : NSObject
{
    unsigned char *_pixbuf;
    CGContextRef _bitmapContext;
}
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) CGSize origSize;
@end

@implementation PixelBuffer
@synthesize size = _size;
@synthesize origSize = _origSize;

void cleanup_pixbuf(void *releaseInfo, void *data)
{
    if (releaseInfo != data) {
        fprintf(stderr, "cleanup_pixbuf: releaseInfo != data\n");
    } else {
        fprintf(stderr, "cleanup_pixbuf: releaseInfo == data\n");
    }
    free(data);
    fprintf(stderr, "cleanup_pixbuf: freed\n");
}

- (void)dealloc {
    if(_bitmapContext) {
        CFRelease(_bitmapContext);
        _bitmapContext = nil;
    }   
    [super dealloc];
}

- (id)initWithSize:(CGSize)s origSize:(CGSize)origSize
{
    self = [super init];
    if (self) {
        self.size = s;
        self.origSize = origSize;
        _pixbuf = (unsigned char *)malloc(s.width*s.height*4);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
        _bitmapContext = CGBitmapContextCreateWithData(_pixbuf,
                                                       s.width,
                                                       s.height,
                                                       8,
                                                       s.width*4,
                                                       colorSpace,
                                                       kCGImageAlphaNoneSkipLast,
                                                       cleanup_pixbuf,
                                                       _pixbuf);
        CFRelease(colorSpace);
    }
    return self;
}

- (unsigned char *)bytes { return _pixbuf; }

- (void)toView:(UIView *)v
{
    if (_bitmapContext) {
        CGImageRef cgImage = CGBitmapContextCreateImage(_bitmapContext);
        v.layer.contents = (id)cgImage;
        CFRelease(cgImage);
    }
}

@end

@interface DjvuGlue : NSObject
@end
@implementation DjvuGlue
@end

@class DjvuDocument;

@interface DjvuSearchTask : NSOperation
@property (nonatomic, retain) DjvuDocument *document;
@property (nonatomic, retain) NSString *keyword;
@property (nonatomic, retain) id onUpdate;
@end

@implementation DjvuSearchTask
@synthesize document = _document;
@synthesize keyword = _keyword;
@synthesize onUpdate = _onUpdate;

- (void)dealloc
{
    self.document = nil;
    [super dealloc];
}

extern "C" {
    id new_nu_cell(id obj);
}

- (void)main
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (![self isCancelled]) {
        BOOL cancelled = NO;
        int npages = [self.document pageCount];
        NSMutableArray *results = [[NSMutableArray alloc] init];
        int nelts = 0;
        for(int i=0; i<npages; i++) {
            if ([self isCancelled]) {
                cancelled = YES;
                break;
            }
            NSArray *arr = [self.document searchPage:i keyword:self.keyword];
            if ([arr count]) {
                NSArray *elt = [NSArray arrayWithObjects:
                                [NSNumber numberWithInt:i+1],
                                arr,
                                nil];
                [results addObject:elt];
                if (i % 20 == 19) {
                    [self performSelectorOnMainThread:@selector(evalOnUpdate:) withObject:[NSArray arrayWithArray:results] waitUntilDone:NO];
                }
                nelts++;
            }
        }
        if (![self isCancelled]) {
            [self performSelectorOnMainThread:@selector(evalOnFinish:) withObject:nil waitUntilDone:NO];
            [self performSelectorOnMainThread:@selector(evalOnUpdate:) withObject:results waitUntilDone:YES];
        }
        [results release];
    }
    [pool drain];
}

- (void)evalOnUpdate:(id)obj
{
    [self.document setSearchResults:obj];
    [self.onUpdate evalWithArguments:[NSNull null]];
}

- (void)evalOnFinish:(id)obj
{
    [self.document setSearchTask:nil];
}

@end


@interface DjvuDocument : NSObject
{
    ddjvu_document_t *_doc;
    miniexp_t _outline;
}
@property (nonatomic, retain) NSString *path;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSArray *searchResults;
@property (nonatomic, retain) DjvuSearchTask *searchTask;
@end
@implementation DjvuDocument
@synthesize path = _path;
@synthesize title = _title;
@synthesize searchResults = _searchResults;
@synthesize searchTask = _searchTask;

- (void)dealloc
{
    [self.searchTask cancel];
    self.searchTask = nil;
    self.searchResults = nil;
    if (_doc) {
        ddjvu_document_release(_doc);
        _doc = nil;
    }
    _outline = NULL;
    self.path = nil;
    self.title = nil;
    [super dealloc];
}

static BOOL handle(int wait)
{
    const ddjvu_message_t *msg;
    if (!djvu_ctx)
        return NO;
    if (wait)
        msg = ddjvu_message_wait(djvu_ctx);
    while ((msg = ddjvu_message_peek(djvu_ctx)))
    {
        switch(msg->m_any.tag)
        {
            case DDJVU_ERROR:
                fprintf(stderr,"djvutxt: %s\n", msg->m_error.message);
                if (msg->m_error.filename)
                    fprintf(stderr,"djvutxt: '%s:%d'\n", 
                            msg->m_error.filename, msg->m_error.lineno);
                return NO;
            default:
                break;
        }
        ddjvu_message_pop(djvu_ctx);
    }
    return YES;
}

- (id)initWithPath:(NSString *)path
{
    NSLog(@"DjvuDocument initWithPath %@", path);
    self = [super init];
    if (self) {
        self.path = path;
        self.title = getDisplayNameForPath(path);
        if (!djvu_ctx)
            djvu_ctx = ddjvu_context_create("soledjvu");
        if (!djvu_ctx) {
            NSLog(@"Unable to create djvu context.");
            return self;
        }
        NSLog(@"djvu cache size %lu", ddjvu_cache_get_size(djvu_ctx));
        static char pathbuf[1024];
        [path getCString:pathbuf maxLength:1024 encoding:NSUTF8StringEncoding];
        _doc = ddjvu_document_create_by_filename_utf8(djvu_ctx, pathbuf, TRUE);
        if (!_doc) {
            NSLog(@"Unable to open file '%s'", pathbuf);
            return self;
        }
        _outline = miniexp_nil;
        while (! ddjvu_document_decoding_done(_doc)) {
            if (!handle(TRUE)) {
                NSLog(@"Unable to decode document.");
                ddjvu_document_release(_doc);
                _doc = nil;
                return self;
            }
        }
        while ((_outline=ddjvu_document_get_outline(_doc))==miniexp_dummy) {
            if (!handle(TRUE)) {
                NSLog(@"Unable to get outline");
                ddjvu_document_release(_doc);
                _doc = nil;
                return self;
            }
        }
    }

    return self;
}

- (BOOL)isLoaded
{
    return (_doc) ? YES : NO;
}

- (int)pageCount
{
    if (!_doc)
        return 0;
    return ddjvu_document_get_pagenum(_doc);
}

- (int)bookmarkCount
{
    if (!_doc)
        return 0;
    if (!miniexp_listp(_outline))
        return 0;
    return maxint(miniexp_length(_outline)-1, 0);
}

- (NSString *)bookmarkTitle:(int)index
{
    if (!_doc)
        return 0;
    if (!miniexp_listp(_outline))
        return 0;
    miniexp_t r = miniexp_nth(index+1, _outline);
    if (miniexp_listp(r)) {
        r = miniexp_car(r);
        if (miniexp_stringp(r)) {
            return [NSString stringWithCString:(const char *)miniexp_to_str(r) encoding:NSUTF8StringEncoding];
        }
    }
    return nil;
}

- (int)bookmarkPageNum:(int)index
{
    if (!_doc)
        return 0;
    if (!miniexp_listp(_outline))
        return 0;
    miniexp_t r = miniexp_nth(index+1, _outline);
    if (miniexp_listp(r)) {
        r = miniexp_nth(1, r);
        if (miniexp_stringp(r)) {
            const char *p = miniexp_to_str(r);
            int page_num = -1;
            if (*p == '#') {
                try {
                    GP<DjVuDocument> internal_doc = ddjvu_get_DjVuDocument(_doc);
                    if (internal_doc) {
                        page_num = internal_doc->id_to_page(p+1);
                        NSLog(@"doc->id_to_page '%s' page_num %d", p, page_num);
                    }
                } catch (...) {
                    page_num = strtol(p+1, 0, 10) - 1;
                    NSLog(@"strtol page_num %d", page_num);
                }
            }
            return page_num;
        }
    }
    return 0;
}

- (PixelBuffer *)renderPage:(int)index maxSize:(CGSize)maxSize
{
    if (!_doc)
        return nil;
    ddjvu_page_t *page = ddjvu_page_create_by_pageno(_doc, index);
    if (!page) {
        NSLog(@"unable to decode page %d", index);
        return nil;
    }
    while (! ddjvu_page_decoding_done(page)) {
        if (!handle(TRUE))
            break;
    }
    if (ddjvu_page_decoding_error(page)) {
        handle(FALSE);
        NSLog(@"error decoding page %d", index);
        return nil;
    }

    CGSize imageSize = CGSizeMake(ddjvu_page_get_width(page), ddjvu_page_get_height(page));
    CGSize s = proportional_size(maxSize.width, maxSize.height, imageSize.width, imageSize.height);
    ddjvu_rect_t prect;
    ddjvu_rect_t rrect;
    prect.x = rrect.x = 0;
    prect.y = rrect.y = 0;
    prect.w = rrect.w = s.width;
    prect.h = rrect.h = s.height;
    
    /* Process mode specification */
    ddjvu_render_mode_t mode = DDJVU_RENDER_COLOR;
    
    /* Determine output pixel format */
    ddjvu_format_style_t style = DDJVU_FORMAT_RGBMASK32;
    unsigned int fmt_args[3];
    fmt_args[0] = 0xff;
    fmt_args[1] = 0xff00;
    fmt_args[2] = 0xff0000;
    ddjvu_format_t *fmt = ddjvu_format_create(style, 3, fmt_args);
    if (!fmt) {
        NSLog(@"unable to create format for page %d", index);
        return nil;
    }
    ddjvu_format_set_row_order(fmt, 1);
    
    /* Allocate buffer */
    int rowsize = rrect.w * 4; 

    PixelBuffer *pixelBuffer = [[[PixelBuffer alloc] initWithSize:s origSize:imageSize] autorelease];
    char *bytes = (char *)[pixelBuffer bytes];

    /* Render */
    if (! ddjvu_page_render(page, mode, &prect, &rrect, fmt, rowsize, bytes)) {
        NSLog(@"unable to render page %d %d %d %d %d %d %d", index, mode, prect.x, prect.y, prect.w, prect.h, rowsize);
        pixelBuffer = nil;
    }
    
    
    /* Free */
    ddjvu_format_release(fmt);

    ddjvu_page_release(page);
    
    return pixelBuffer;
}

- (void)processSearch:(miniexp_t)r keyword:(NSString *)keyword results:(NSMutableArray *)results
{
    int len = miniexp_length(r);
    for(int i=5; i<len; i++) {
        miniexp_t q = miniexp_nth(i, r);
        if (!q)
            continue;
        if (miniexp_listp(q)) {
            [self processSearch:q keyword:keyword results:results];
        } else if (miniexp_stringp(q)) {
            const char *cstr = miniexp_to_str(q);
            if (cstr) {
                NSString *str = [NSString stringWithCString:cstr encoding:NSASCIIStringEncoding];
                NSRange range = [str rangeOfString:keyword options:NSCaseInsensitiveSearch];
                if (range.location != NSNotFound) {
//                    NSLog(@"processSearch: match keyword '%@' in '%@' '%s'", keyword, str, cstr);
                    miniexp_t n1, n2, n3, n4;
                    n1 = miniexp_nth(1, r);
                    n2 = miniexp_nth(2, r);
                    n3 = miniexp_nth(3, r);
                    n4 = miniexp_nth(4, r);
                    if (n1 && miniexp_numberp(n1)
                        && n2 && miniexp_numberp(n2)
                        && n3 && miniexp_numberp(n3)
                        && n4 && miniexp_numberp(n4))
                    {
                        NSArray *rect = [NSArray arrayWithObjects:
                                        [NSNumber numberWithInt:miniexp_to_int(n1)],
                                        [NSNumber numberWithInt:miniexp_to_int(n2)],
                                        [NSNumber numberWithInt:miniexp_to_int(n3)],
                                        [NSNumber numberWithInt:miniexp_to_int(n4)],
                                        nil];
                        [results addObject:rect];
                    } else {
                        NSLog(@"match but coords not found");
                    }
                }
            }
        }
    }
}

- (id)searchPage:(int)pageno keyword:(NSString *)keyword
{
    NSMutableArray *results = [[[NSMutableArray alloc] init] autorelease];

    if (!_doc)
        return results;
    
    miniexp_t r = miniexp_nil;
    while ((r = ddjvu_document_get_pagetext(_doc,pageno,"line"))==miniexp_dummy) {
        if (!handle(TRUE)) {
            NSLog(@"Unable to search page %d", pageno);
            return results;
        }
    }
    if (r) {
        [self processSearch:r keyword:keyword results:results];
    }
    return results;
}

- (void)search:(NSString *)keyword onUpdate:(id)onUpdate
{
    [self.searchTask cancel];
    self.searchTask = nil;
    self.searchResults = nil;
    if (_doc && [keyword length]) {
        self.searchTask = [[[DjvuSearchTask alloc] init] autorelease];
        [self.searchTask setDocument:self];
        [self.searchTask setKeyword:keyword];
        [self.searchTask setOnUpdate:onUpdate];
        [self.searchTask setQueuePriority:NSOperationQueuePriorityHigh];
        [onUpdate evalWithArguments:[NSNull null]];
        [[[[UIApplication sharedApplication] delegate] taskQueue] addOperation:self.searchTask];
    } else {
        [onUpdate evalWithArguments:[NSNull null]];
    }
}

@end

@interface DjvuRenderTask : NSOperation
@property (nonatomic, retain) DjvuDocument *document;
@property (nonatomic, assign) int index;
@property (nonatomic, assign) CGSize maxSize;
@property (nonatomic, retain) UIView *view;
@property (nonatomic, retain) PixelBuffer *pixbuf;
@end



@implementation DjvuRenderTask
@synthesize document = _document;
@synthesize index = _index;
@synthesize maxSize = _maxSize;
@synthesize view = _view;
@synthesize pixbuf = _pixbuf;

- (void)dealloc
{
    self.pixbuf = nil;
    self.document = nil;
    self.view = nil;
    [super dealloc];
}

- (void)main
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (![self isCancelled]) {
        self.pixbuf = [self.document renderPage:self.index maxSize:self.maxSize];
        [self.view performSelectorOnMainThread:@selector(taskDone:) withObject:self waitUntilDone:YES];
    }
    [pool drain];
}

@end



@interface ZoomingScrollView : UIScrollView <UIScrollViewDelegate> {
    DjvuPageView        *pageView;
}
@property (nonatomic, assign) int index;
@property (nonatomic, retain) DjvuRenderTask *task;
@end

@implementation ZoomingScrollView
@synthesize index = _index;
@synthesize task = _task;

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.bouncesZoom = YES;
        self.decelerationRate = UIScrollViewDecelerationRateFast;
        self.delegate = self;        
    }
    return self;
}

- (void)dealloc
{
    [self.task cancel];
    self.task = nil;
    [pageView release];
    pageView = nil;
    [super dealloc];
}

- (DjvuPageView *)pageView { return pageView; }

- (void)layoutSubviews 
{
    [super layoutSubviews];
    
    CGSize s;
    if (!pageView.origSize.width || !pageView.origSize.height) {
        s = self.bounds.size;
    } else if (self.zoomScale > 1.0) {
        s = proportional_size(self.frame.size.width*self.zoomScale, self.frame.size.height*self.zoomScale, pageView.origSize.width, pageView.origSize.height);
    } else if (self.zooming) {
        s = pageView.frame.size;
    } else {
        s = self.frame.size;
    }
    NSLog(@"layoutSubviews: %.f %.f", s.width, s.height);
    pageView.frame = center_rect_in_size(CGRectMake(0.0, 0.0, s.width, s.height), self.frame.size);
    self.contentSize = pageView.frame.size;

    /*    if ([pageView isKindOfClass:[TilingView class]]) {
     // to handle the interaction between CATiledLayer and high resolution screens, we need to manually set the
     // tiling view's contentScaleFactor to 1.0. (If we omitted this, it would be 2.0 on high resolution screens,
     // which would cause the CATiledLayer to ask us for tiles of the wrong scales.)
     pageView.contentScaleFactor = 1.0;
     }*/
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return pageView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale
{
    NSLog(@"scrollViewDidEndZooming:%f", scale);
    [[self pageView] highlightSearchResults];
    [self renderTask];
}

- (void)displayPage
{
    // clear the previous imageView
    [pageView removeFromSuperview];
    [pageView release];
    pageView = nil;
    
    self.zoomScale = 1.0;
    
    pageView = [[DjvuPageView alloc] initWithFrame:self.bounds];
    [pageView.activityView startAnimating];
    [self addSubview:pageView];
    self.contentSize = pageView.bounds.size;
    self.minimumZoomScale = 1.0;
    self.maximumZoomScale = 1.0;

    [self renderTask];
}

- (void)zoomOutPage
{
    self.zoomScale = 1.0;
    pageView.frame = self.bounds;
    self.contentSize = pageView.bounds.size;
    [self renderTask];
}

- (void)renderTask
{
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGSize scaledSize = CGSizeMake(pageView.frame.size.width*scale, pageView.frame.size.height*scale);
    if ((pageView.renderSize.width == scaledSize.width) 
        && (pageView.renderSize.height == scaledSize.height))
    {
        NSLog(@"renderTask: renderSize %.f %.f == scaledSize %.f %.f", pageView.renderSize.width, pageView.renderSize.height, scaledSize.width, scaledSize.height);
        return;
    }
    DjvuDocument *document = [[self superview] document];
    if (!document) {
        NSLog(@"renderTask: zoomingscrollview %x no document", self);
        return;
    }

    [self.task cancel];
    self.task = [[[DjvuRenderTask alloc] init] autorelease];
    [self.task setDocument:document];
    [self.task setIndex:self.index];
    [self.task setMaxSize:scaledSize];
    [self.task setView:self];
    [[[[UIApplication sharedApplication] delegate] taskQueue] addOperation:(NSOperation *)self.task];
    NSLog(@"renderTask zoomingscrollview %x task %x index %d maxSize %.f %.f", self, self.task, self.index, scaledSize.width, scaledSize.height);
}

- (void)taskDone:(DjvuRenderTask *)task
{
    NSLog(@"taskDone page %d", task.index);
    if (self.task == task) {
        [pageView.activityView stopAnimating];
        if (![task isCancelled]) {
            if (task.pixbuf) {
                CGFloat scale = [[UIScreen mainScreen] scale];
                pageView.frame = center_rect_in_size(CGRectMake(0.0, 0.0, task.pixbuf.size.width/scale, task.pixbuf.size.height/scale), self.frame.size);
                pageView.renderSize = task.pixbuf.size;
                pageView.origSize = task.pixbuf.origSize;
                pageView.layer.contentsGravity = kCAGravityResizeAspect;
                [task.pixbuf toView:pageView];
                self.minimumZoomScale = 1.0;
                self.maximumZoomScale = 2.5;
                [pageView highlightSearchResults];
            } else {
                UIImage *image = [Glue imageWithString:@"(this page intentionally left blank)" font:[UIFont systemFontOfSize:12.0]];
                pageView.frame = center_rect_in_size(CGRectMake(0.0, 0.0, image.size.width, image.size.height), self.frame.size);
                pageView.renderSize = CGSizeMake(image.size.width,image.size.height);
                pageView.origSize = CGSizeMake(image.size.width,image.size.height);
                pageView.layer.contentsGravity = kCAGravityCenter;
                pageView.layer.contents = (id)image.CGImage;
                pageView.layer.contentsScale = image.scale;
                self.minimumZoomScale = 1.0;
                self.maximumZoomScale = 1.0;
            }
        } else {
            NSLog(@"taskDone: cancelled");
        }
        self.task = nil;
    } else {
        NSLog(@"taskDone: discarding old task %p %d != %p %d", self.task, self.task.index, task, task.index);
    }
}

- (void)removeFromSuperview
{
    [self.task cancel];
    self.task = nil;
    pageView.layer.contents = nil;
    [super removeFromSuperview];
}

@end




@interface PagingScrollView : UIScrollView <UIScrollViewDelegate> 
{
    BOOL _scrollViewDidNotScrollStupidApple;
}

- (void)configurePage:(id)page forIndex:(NSUInteger)index;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;

- (CGRect)frameForPageAtIndex:(NSUInteger)index;

- (void)tilePages;
- (id)dequeueRecycledPage;
@property (nonatomic, retain) id nuDelegate;
@property (nonatomic, retain) NSMutableSet *recycledPages;
@property (nonatomic, retain) NSMutableSet *visiblePages;
@property (nonatomic, retain) DjvuDocument *document;
@property (nonatomic, assign) CGFloat padding;
@end


@implementation PagingScrollView
@synthesize nuDelegate = _nuDelegate;
@synthesize recycledPages = _recycledPages;
@synthesize visiblePages = _visiblePages;
@synthesize document = _document;
@synthesize padding = _padding;

- (void)dealloc
{
    self.nuDelegate = nil;
    self.recycledPages = nil;
    self.visiblePages = nil;
    self.document = nil;
    [super dealloc];
}

- (id)initWithFrame:(CGRect)frame padding:(CGFloat)padding document:(DjvuDocument *)document page:(int)page
{    
    log_rect(@"PagingScrollView initWithFrame:", frame);
    self = [super initWithFrame:[self addPadding:padding toFrame:frame]];
    if (self) {
        self.padding = padding;
        self.document = document;
        self.pagingEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.contentSize = CGSizeMake(self.bounds.size.width * [self pageCount], self.bounds.size.height);
        self.delegate = self;
        
        self.recycledPages = [[[NSMutableSet alloc] init] autorelease];
        self.visiblePages  = [[[NSMutableSet alloc] init] autorelease];
        self.contentOffset = [self getContentOffsetForPage:page];
        [self tilePages];
    }
    return self;
}

- (void)visiblePagesFrames
{
    NSLog(@"visiblePagesFrames");
    for (UIView *v in self.visiblePages) {
        log_rect(@"visiblePage", v.frame);
    }
}

- (NSUInteger)pageCount
{
    return [self.document pageCount];
}

- (void)setFrame:(CGRect)frame
{
    _scrollViewDidNotScrollStupidApple = YES;
    CGFloat xoffset = self.contentOffset.x / self.frame.size.width;
    CGRect r = [self addPadding:self.padding toFrame:frame];
    [super setFrame:r];
    self.contentOffset = CGPointMake(r.size.width*xoffset, 0);
    NSLog(@"setFrame %f %f", self.contentOffset.x, self.frame.size.width);
    self.contentSize = CGSizeMake(r.size.width * [self pageCount], r.size.height);
    [self layoutIfNeeded];
    _scrollViewDidNotScrollStupidApple = NO;
    [self tilePages];
    [self renderVisiblePages];
}

static CGRect paddingToRect(CGSize s, CGRect r)
{
    return CGRectMake(r.origin.x - s.width,
                      r.origin.y - s.height,
                      r.size.width + s.width*2.0,
                      r.size.height + s.height*2.0);
}

- (CGRect)addPadding:(CGFloat)padding toFrame:(CGRect)r
{
    return paddingToRect(CGSizeMake(padding, 0.0), r);
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect pageFrame = self.bounds;
    pageFrame.size.width -= (2 * self.padding);
    pageFrame.origin.x = (self.bounds.size.width * index) + self.padding;
    return pageFrame;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    NSArray *arr = [self.visiblePages allObjects];
    for (ZoomingScrollView *v in arr) {
        v.frame = [self frameForPageAtIndex:v.index];
    }
}


- (UIView *)dequeueRecycledPage
{
    UIView *page = [self.recycledPages anyObject];
    if (page) {
        [[page retain] autorelease];
        [self.recycledPages removeObject:page];
    }
    return page;
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index
{
    BOOL foundPage = NO;
    for (ZoomingScrollView *page in self.visiblePages) {
        if (page.index == index) {
            foundPage = YES;
            break;
        }
    }
    return foundPage;
}

- (void)configurePage:(ZoomingScrollView *)page forIndex:(NSUInteger)index
{
    page.index = index;
    page.frame = [self frameForPageAtIndex:index];
    
    [page displayPage];
    // Use tiled images
//    [page displayTiledImageNamed:[self imageNameAtIndex:index]
//                            size:[self imageSizeAtIndex:index]];
    
    // To use full images instead of tiled images, replace the "displayTiledImageNamed:" call
    // above by the following line:
    // [page displayImage:[self imageAtIndex:index]];
}

static NSComparisonResult compare_float(float a, float b)
{
    if (a < b)
        return NSOrderedAscending;
    if (a > b)
        return NSOrderedDescending;
    return NSOrderedSame;
}

static float render_sort_order(int index, int base_index)
{
    float val;
    val = index - base_index;
    if (val < 0.0)
        val = (val * -1.0) + 0.5;
    return val;
}

- (int)visiblePageIndex
{
    return floorf((self.contentOffset.x + (self.frame.size.width/2.0)) / self.frame.size.width);
}

- (void)tilePages:(int)before after:(int)after
{
//    NSLog(@"tilePages");
    // Calculate which pages are visible
    int visiblePageIndex = [self visiblePageIndex];
    int firstNeededPageIndex = visiblePageIndex + before;
    int lastNeededPageIndex  = visiblePageIndex + after;
    int pageCountMinusOne = [self pageCount] - 1;
    firstNeededPageIndex = maxint(firstNeededPageIndex, 0);
    lastNeededPageIndex  = minint(lastNeededPageIndex, pageCountMinusOne);
    
    int lastVisiblePageIndex  = floorf((self.contentOffset.x+self.frame.size.width-1) / self.frame.size.width);
    lastVisiblePageIndex  = minint(lastVisiblePageIndex, pageCountMinusOne);
    
    // Recycle no-longer-visible pages 
    for (ZoomingScrollView *page in self.visiblePages) {
        if ((page.index < firstNeededPageIndex) || (page.index > lastNeededPageIndex)) {
            NSLog(@"recycling page %d (%d %d %d)", page.index, visiblePageIndex, firstNeededPageIndex, lastNeededPageIndex);
            NSLog(@"bounds %f %f", self.bounds.size.width, self.bounds.size.height);
            NSLog(@"visiblePageIndex %f %f", CGRectGetMinX(self.bounds), CGRectGetWidth(self.bounds));
            NSLog(@"contentOffset %f", self.contentOffset.x);
            [self.recycledPages addObject:page];
            [page removeFromSuperview];
        }
    }
    [self.visiblePages minusSet:self.recycledPages];
    
    NSArray *zoomOutArr = [self.visiblePages allObjects];
    
    for (ZoomingScrollView *page in zoomOutArr) {
        if ((page.index < visiblePageIndex) || (page.index > lastVisiblePageIndex)) {
            if (page.zoomScale > 1.0) {
                NSLog(@"setting zoomScale 1.0 index %d", page.index);
                [page zoomOutPage];
            }
        }
    }

    NSMutableArray *renderArr = [[[NSMutableArray alloc] init] autorelease];

    // add missing pages
    for (int index = firstNeededPageIndex; index <= lastNeededPageIndex; index++) {
        if (![self isDisplayingPageForIndex:index]) {
            NSLog(@"renderArr addObject:%d", index);
            [renderArr addObject:[NSNumber numberWithInt:index]];
        }
    }
    
    [renderArr sortUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return compare_float(render_sort_order(obj1.intValue, visiblePageIndex),
                             render_sort_order(obj2.intValue, visiblePageIndex));
    }];
    for (NSNumber *elt in renderArr) {
        UIView *page = [self dequeueRecycledPage];
        if (page == nil) {
            page = [[[ZoomingScrollView alloc] initWithFrame:CGRectZero] autorelease];
        }
        [self addSubview:page];
        [self configurePage:page forIndex:elt.intValue];
        [self.visiblePages addObject:page];
    }
}

- (void)renderVisiblePages
{
    int visiblePageIndex = [self visiblePageIndex];
    visiblePageIndex = maxint(visiblePageIndex, 0);
    NSMutableArray *renderArr = [NSMutableArray arrayWithArray:[self.visiblePages allObjects]];
    [renderArr sortUsingComparator:^NSComparisonResult(ZoomingScrollView *obj1, ZoomingScrollView *obj2) {
        return compare_float(render_sort_order(obj1.index, visiblePageIndex),
                             render_sort_order(obj2.index, visiblePageIndex));
    }];
    [self highlightSearchResults];
    for (ZoomingScrollView *elt in renderArr) {
        [elt renderTask];
    }
}

- (void)tilePages
{
    [self tilePages:-2 after:2];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
//    NSLog(@"scrollViewDidScroll");
    if (_scrollViewDidNotScrollStupidApple)
        return;
    [self tilePages];
    if (self.nuDelegate) {
        [self.nuDelegate evalWithArguments:[NSNull null]];
    }
}

- (int)pageIndexFromFloat:(float)val
{
    return (int)((val*(self.contentSize.width-self.frame.size.width)+self.frame.size.width/2.0)/self.frame.size.width);
}

- (CGFloat)floatOfVisiblePage
{
    CGFloat visiblePage = [self visiblePageIndex];
    CGFloat pageCount = [self pageCount] - 1;
    if (pageCount < 0.0)
        return 0.0;
    CGFloat val = visiblePage / pageCount;
    if (val < 0.0)
        val = 0.0;
    if (val > 1.0)
        val = 1.0;
    return val;
}

- (CGPoint)getContentOffsetForPage:(int)index
{
    return CGPointMake(self.frame.size.width*index, 0.0);
}

- (void)goToPage:(int)index
{
    if ((index < 0) || (index >= [self pageCount]))
        return;
    self.contentOffset = [self getContentOffsetForPage:index];
}

- (void)highlightSearchResults
{
    for (ZoomingScrollView *v in self.visiblePages) {
        [[v pageView] highlightSearchResults];
    }
}

@end


