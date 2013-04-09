//
//  Misc.m
//  Nu
//
//  Created by arthur on 24/09/12.
//
//

#import <Foundation/Foundation.h>

CGRect center_rect_in_size(CGRect sm, CGSize lg)
{
    // center the image as it becomes smaller than the size of the screen
    
    CGSize boundsSize = lg;
    CGRect frameToCenter = sm;
    
    // center horizontally
    if (frameToCenter.size.width < boundsSize.width)
        frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2;
    else
        frameToCenter.origin.x = 0;
    
    // center vertically
    if (frameToCenter.size.height < boundsSize.height)
        frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2;
    else
        frameToCenter.origin.y = 0;
    
    return frameToCenter;
}

CGSize proportional_size(int w, int h, int origw, int origh)
{
    int tmp_width = w;
    int tmp_height = ((((tmp_width * origh) / origw)+7)&~7);
    if(tmp_height > h)
    {
        tmp_height = h;
        tmp_width = ((((tmp_height * origw) / origh)+7)&~7);
    }
    return CGSizeMake(tmp_width, tmp_height);
}

NSString *get_docs_path()
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

NSString *path_in_docs(NSString *name)
{
    return [[get_docs_path() stringByAppendingPathComponent:name] stringByStandardizingPath];
}

NSString *url_encode(NSString *str)
{
    return (NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                               NULL,
                                                               (CFStringRef)str,
                                                               NULL,
                                                               (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                               kCFStringEncodingUTF8 );
}

NSString *path_encode(NSString *str)
{
    return (NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                               NULL,
                                                               (CFStringRef)str,
                                                               NULL,
                                                               (CFStringRef)@"/%",
                                                               kCFStringEncodingUTF8 );
}

void show_alert(NSString *title, NSString *message, NSString *cancel)
{
    NSLog(@"UIAlertView crashes a lot in iOS 6 because the code is getting worse over time");
    NSLog(@"Here is what would have been displayed, title '%@' message '%@' cancel '%@'", title, message, cancel);
/*    UIAlertView *v = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancel otherButtonTitles:nil];
    [v show];
    [v release];*/
}

