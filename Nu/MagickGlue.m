//
//  MagickGlue.m
//  Nu
//
//  Created by arthur on 30/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "wand/MagickWand.h"

@interface MagickGlue : NSObject

@end

@implementation MagickGlue

static int magickCommandGenesis(MagickCommand command, id arr)
{
    ExceptionInfo *exception;
    ImageInfo *image_info;
    MagickBooleanType status;
    
    if ([arr count] == 0) {
        return 0;
    }
    char **argv = malloc([arr count] * sizeof(char *));
    for(int i=0; i<[arr count]; i++) {
        argv[i] = (char *) [[arr objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    prn([NSString stringWithFormat:@"magickCommandGenesis %@", arr]);
    
    MagickCoreGenesis(*argv,MagickTrue);
    exception=AcquireExceptionInfo();
    image_info=AcquireImageInfo();
    SetMagickResourceLimit(MemoryResource, 0);
    ListMagickResourceInfo(stderr, exception);
    status=MagickCommandGenesis(image_info,command,[arr count],argv,
                                (char **) NULL,exception);
    image_info=DestroyImageInfo(image_info);
    exception=DestroyExceptionInfo(exception);
    MagickCoreTerminus();
    
    free(argv);
    
    return(status);
}

+ (int)convert:(id)lst
{
    return magickCommandGenesis(ConvertImageCommand, lst);
}

+ (int)composite:(NSArray *)arr
{
    return magickCommandGenesis(CompositeImageCommand, arr);
}


@end
