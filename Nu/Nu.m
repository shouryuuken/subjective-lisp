/*!
 @file Nu.m
 @description Nu.
 @copyright Copyright (c) 2007-2011 Radtastical Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


#import <AvailabilityMacros.h>
#import <Foundation/Foundation.h>
#import <unistd.h>

#import <CoreGraphics/CoreGraphics.h>
#define NSRect CGRect
#define NSPoint CGPoint
#define NSSize CGSize

#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <stdint.h>
#import <math.h>
#import <time.h>
#import <sys/stat.h>
#import <sys/mman.h>

#import <mach/mach.h>
#import <mach/mach_time.h>

#import <UIKit/UIKit.h>

#import "ffi.h"

#import <dlfcn.h> 

#import "Nu.h"

#define NU_CCTYPES
#ifdef NU_CCTYPES
#import "ccTypes.h"
#endif

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
//#import "ObjectiveChipmunk.h"

#import "Misc.h"

id Nu__null = 0;
id Nu__t = 0;

bool nu_valueIsNull(id value)
{
    return (!value || (value == Nu__null));
}

bool nu_valueIsTrue(id value)
{
    bool result = value && (value != Nu__null);
    if (result && nu_objectIsKindOfClass(value, [NSNumber class])) {
        if ([value doubleValue] == 0.0)
            result = false;
    }
    return result;
}

NuCell *nucons1(NuCell *lst, id obj)
{
    NuCell *cdr = nucell(obj, nil);
    [lst setCdr:cdr];
    return cdr;
}

id nuuint8(uint8_t val)
{
    return [NSNumber numberWithUnsignedInt:val];
}

id nuuint16(uint16_t val)
{
    return [NSNumber numberWithUnsignedInt:val];
}

id nuuint32(uint32_t val)
{
    return [NSNumber numberWithUnsignedInt:val];
}

id nufloat(float val)
{
    return [NSNumber numberWithFloat:val];
}

id string_from_file(NSString *path)
{
    return [NSString stringWithContentsOfFile:path
                                     encoding:NSUTF8StringEncoding
                                        error:nil];
}

BOOL is_directory(NSString *path)
{
    BOOL val = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&val]) {
        return val;
    }
    return NO;
}

id get_directory_extension(NSString *path)
{
    if (is_directory(path)) {
        NSString *ext = [path pathExtension];
        if ([ext length]) {
            return ext;
        }
    }
    return get_directory_extension([path stringByDeletingLastPathComponent]);
}

id path_to_symbols()
{
    return path_in_docs(@"symbols.nu");
}

id path_to_namespace(NSString *name)
{
    return [path_to_symbols() stringByAppendingPathComponent:path_encode(name)];
}

id path_to_symbol(NSString *namespace, NSString *symbol)
{
    id str = [path_to_namespace(namespace) stringByAppendingPathComponent:path_encode(symbol)];
    return str;
}

id read_symbol(NSString *namespace, NSString *symbol)
{
    id value = [NSString stringWithContentsOfFile:path_to_symbol(namespace, symbol) encoding:NSUTF8StringEncoding error:nil];
    if (!value)
        value = Nu__null;
    return value;
}

int write_symbol_to_file(NSString *namespace, NSString *name, id contents)
{
    [[NSFileManager defaultManager] createDirectoryAtPath:path_to_namespace(namespace) withIntermediateDirectories:YES attributes:nil error:nil];
    if (nu_objectIsKindOfClass(contents, [NSString class])) {
        return [contents writeToFile:path_to_symbol(namespace, name)
                          atomically:YES
                            encoding:NSUTF8StringEncoding
                               error:nil];
    }
    if (nu_objectIsKindOfClass(contents, [NSData class])) {
        return [contents writeToFile:path_to_symbol(namespace, name)
                               atomically:YES];
    }
    return 0;
}

void clear_symbol_after_write(NSString *name)
{
    NuSymbol *symbol = [[NuSymbolTable sharedSymbolTable] lookup:name];
    id value = [symbol value];
    if (value) {
        if (nu_objectIsKindOfClass(value, [NuBlock class])
            || nu_objectIsKindOfClass(value, [NuMacro_1 class])
            || nu_objectIsKindOfClass(value, [NSNull class])) {
            prn([NSString stringWithFormat:@"clearing value for symbol %@", name]);
            [symbol setValue:nil];
        } else {
            prn([NSString stringWithFormat:@"symbol %@ not a block or NSNull, not clearing", name]);
        }
    } else {
        prn([NSString stringWithFormat:@"no global value for symbol %@", name]);
    }
}

int write_symbol(NSString *namespace, NSString *name, id contents)
{
    if (!write_symbol_to_file(namespace, name, contents)) {
        return 0;
    }
    clear_symbol_after_write(name);
    return 1;
}

int clear_symbol(NSString *name)
{
    NuSymbol *symbol = [[NuSymbolTable sharedSymbolTable] lookup:name];
    id value = [symbol value];
    if (value) {
        [symbol setValue:nil];
        return 1;
    }
    return 0;
}

int nu_debug_mode()
{
    return [get_symbol_value(@"debug-mode") intValue];
}

NSArray *nu_namespaces()
{
    static NSMutableArray *namespaces = nil;
    if (namespaces)
        return namespaces;
    namespaces = [[NSMutableArray alloc] init];
    NSArray *external = [[path_to_symbols() directoriesInDirectory] sort];
    for (id elt in external) {
        if ([elt hasPrefix:@"."]) {
            continue;
        }
        [namespaces addObject:elt];
    }
    NSArray *internal = [[[[NuSymbolTable sharedSymbolTable] builtin] allKeys] sort];
    [namespaces addObjectsFromArray:internal];
    return namespaces;
}

/*
id symbol_namespace(NSString *name)
{
    id cursor = nu_namespaces();
    id car;
    while (cursor && (cursor != Nu__null)) {
        car = [cursor car];
        if (car && nu_objectIsKindOfClass(car, [NSString class])) {
            if (string_from_file(path_to_symbol(car, name))) {
                return car;
            }
        }
        cursor = [cursor cdr];
    }
    return Nu__null;
    
}
*/

id nu_symbol_from_namespaces(NSString *name)
{
    id str = nil, path = nil;
    NSDictionary *downloaded_symbols = [[[UIApplication sharedApplication] delegate] symbols];
    if (downloaded_symbols) {
        path = [NSString stringWithFormat:@"downloaded: %@", name];
        str = [downloaded_symbols objectForKey:name];
    }
    if (!str) {
        id lst = nu_namespaces();
        for (id elt in lst) {
            if (elt && nu_objectIsKindOfClass(elt, [NSString class])) {
                path = path_to_symbol(elt, name);
                str = string_from_file(path);
                if (str) {
                    break;
                }
                str = [[NuSymbolTable sharedSymbolTable] builtinForKeyPath:[NSArray arrayWithObjects:elt, name, nil]];
                if (str) {
                    if (nu_objectIsKindOfClass(str, [NSString class])) {
                        path = [NSString stringWithFormat:@"builtin %@: %@", elt, name];
                        break;
                    } else {
                        return str;
                    }
                }
            }
        }
    }
    if (str) {
        [[Nu sharedParser] setFilename:path];
        id result = nil;
        @try {
            id script = [[Nu sharedParser] parse:str];
            if (script) {
                result = [[Nu sharedParser] eval:script];
            }
        }
        @catch (NuException* nuException) {
            [nuException addFunction:@"jklfdkl" lineNumber:666 filename:path];
            @throw nuException;
        }
        @catch (NSException* e) {
            if (   nu_objectIsKindOfClass(e, [NuBreakException class])
                || nu_objectIsKindOfClass(e, [NuContinueException class])
                || nu_objectIsKindOfClass(e, [NuReturnException class])) {
                @throw e;
            }
            else {
                NuException* nuException = [[NuException alloc] initWithName:[e name]
                                                                      reason:[e reason]
                                                                    userInfo:[e userInfo]];
                [nuException addFunction:@"pqls" lineNumber:999 filename:path];
                @throw nuException;
            }
        }
        return result;
    }
    return nil;
}

void init_namespace(NSString *name)
{
    NSString *path = path_to_namespace(name);
    if (!is_directory(path)) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

void pr(NSString *str)
{
    [[[[UIApplication sharedApplication] delegate] nuServer] pr:str];
}

void prn(NSString *str)
{
    [[[[UIApplication sharedApplication] delegate] nuServer] prn:str];
}

id get_symbol_value_with_context(NSString *name, NSMutableDictionary *context)
{
    @try {
        id symbol = [[NuSymbolTable sharedSymbolTable] symbolWithString:name];
        if (!context) {
            context = [[Nu sharedParser] context];
        }
        return [symbol evalWithContext:context];
    }
    @catch (NuException* nuException) {
        prn([NSString stringWithFormat:@"%s", [[nuException dump] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    @catch (id exception) {
        prn([NSString stringWithFormat:@"%s: %s",
             [[exception name] cStringUsingEncoding:NSUTF8StringEncoding],
             [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    return nil;
}

id get_symbol_value(NSString *name)
{
    return get_symbol_value_with_context(name, [[Nu sharedParser] context]);
}

id eval_block_core(id block, id args)
{
    @try {
        if (nu_objectIsKindOfClass(block, [NuBlock class])) {
            return [block evalWithArguments:args];
        }
    }
    @catch (NuException* nuException) {
        prn([NSString stringWithFormat:@"%s", [[nuException dump] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    @catch (id exception) {
        prn([NSString stringWithFormat:@"%s: %s",
             [[exception name] cStringUsingEncoding:NSUTF8StringEncoding],
             [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    
    
    return nil;
}

id eval_block(id block, ...)
{
	va_list ap;
	id lst = nil, cursor = nil, obj;
	va_start(ap, block);
    for(;;) {
        obj = va_arg(ap, id);
        if (!obj)
            break;
		cursor = nucons1(cursor, obj);
		if (!lst) {
			lst = cursor;
		}
	}
	va_end(ap);
	return eval_block_core(block, lst);
}

id eval_function_core(NSString *name, id lst)
{
	return eval_block_core(get_symbol_value(name), lst);
}

id eval_function(NSString *name, ...)
{
	va_list ap;
	id lst = nil, cursor = nil, obj;
	va_start(ap, name);
    for(;;) {
        obj = va_arg(ap, id);
        if (!obj)
            break;
		cursor = nucons1(cursor, obj);
		if (!lst) {
			lst = cursor;
		}
	}
	va_end(ap);
	return eval_block_core(get_symbol_value(name), lst);
}

id eval_block_with_self_core(id self, id context, id block, id args)
{
    @try {
        if (nu_objectIsKindOfClass(block, [NuBlock class])) {
            return [block evalWithArguments:args context:(context) ? context : [[Nu sharedParser] context] self:self];
        }
    }
    @catch (NuException* nuException) {
        prn([NSString stringWithFormat:@"%s", [[nuException dump] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    @catch (id exception) {
        prn([NSString stringWithFormat:@"%s: %s",
             [[exception name] cStringUsingEncoding:NSUTF8StringEncoding],
             [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    
    
    return nil;
}

id eval_block_with_self(id self, id context, id block, ...)
{
	va_list ap;
	id lst = nil, cursor = nil, obj;
	va_start(ap, block);
    for(;;) {
        obj = va_arg(ap, id);
        if (!obj)
            break;
		cursor = nucons1(cursor, obj);
		if (!lst) {
			lst = cursor;
		}
	}
	va_end(ap);
	return eval_block_with_self_core(self, context, block, lst);
}

id nu_to_string(NSString *name)
{
    id value = get_symbol_value(name);
    if (nu_objectIsKindOfClass(value, [NSString class])) {
        return value;
    }
    return nil;
}


// We'd like for this to be in the ObjC2 API, but it isn't.
void nu_class_addInstanceVariable_withSignature(Class thisClass, const char *variableName, const char *signature);

// These are handy.
IMP nu_class_replaceMethod(Class cls, SEL name, IMP imp, const char *types);
BOOL nu_copyInstanceMethod(Class destinationClass, Class sourceClass, SEL selector);
BOOL nu_copyInstanceMethodToSelf(Class sourceClass, SEL sourceSelector, SEL destinationSelector);
void nu_markEndOfObjCTypeString(char *type, size_t len);

// This makes it safe to insert nil into container classes
void nu_swizzleContainerClasses(void);

id add_method_to_class(Class c, NSString *methodName, NSString *signature, NuBlock *block);
id nu_calling_objc_method_handler(id target, Method m, NSMutableArray *args);
id get_nu_value_from_objc_value(void *objc_value, const char *typeString);
void *value_buffer_for_objc_type(const char *typeString);
size_t size_of_objc_type(const char *typeString);

IMP handler_with_selector(SEL sel, NuBlock *block, const char *signature, char **userdata);

#pragma mark - NuHandler.h

struct handler_description
{
    IMP handler;
    char **description;
};

void nu_handler(void *return_value,
                       struct handler_description *description, 
                       id receiver, 
                       va_list ap);


#pragma mark - NuInternals.h



#pragma mark - DTrace macros

/*
 * Generated by dtrace(1M).
 */


#pragma mark - NuMain


void transplant_nu_methods(Class destination, Class source)
{
    if (!nu_copyInstanceMethod(destination, source, @selector(evalWithArguments:context:)))
        NSLog(@"method copy failed");
    if (!nu_copyInstanceMethod(destination, source, @selector(sendMessage:withContext:)))
        NSLog(@"method copy failed");
    if (!nu_copyInstanceMethod(destination, source, @selector(stringValue)))
        NSLog(@"method copy failed");
    if (!nu_copyInstanceMethod(destination, source, @selector(evalWithContext:)))
        NSLog(@"method copy failed");
    if (!nu_copyInstanceMethod(destination, source, @selector(handleUnknownMessage:withContext:)))
        NSLog(@"method copy failed");
}

void NuInit()
{
    static BOOL initialized = NO;
    if (initialized) {
        return;
    }
    initialized = YES;        
    @autoreleasepool {            
        // as a convenience, we set a file static variable to nil.
        Nu__null = [NSNull null];
        Nu__t = [[NuSymbolTable sharedSymbolTable] symbolWithString:@"t"];
        load_builtins();
        
        // create "<<" messages that append their arguments to arrays, sets, and strings
        id parser = [Nu sharedParser];
        [[NuClass classWithClass:[NSMutableArray class]] 
         addInstanceMethod:@"<<" 
         signature:@"v*" 
         body:[parser eval:[parser parse:@"(fn (value) (self addObject:value))"]]];        
        [[NuClass classWithClass:[NSMutableSet class]] 
         addInstanceMethod:@"<<" 
         signature:@"v*" 
         body:[parser eval:[parser parse:@"(fn (value) (self addObject:value))"]]];        
        [[NuClass classWithClass:[NSMutableString class]] 
         addInstanceMethod:@"<<" 
         signature:@"v*"
         body:[parser eval:[parser parse:@"(fn (object) (self appendString:(object stringValue)))"]]];
        nu_copyInstanceMethodToSelf([NSArray class], @selector(description), @selector(stringValue));
        nu_copyInstanceMethodToSelf([NSArray class], @selector(superDescription), @selector(description));
        nu_copyInstanceMethodToSelf([NSDictionary class], @selector(description), @selector(stringValue));
        nu_copyInstanceMethodToSelf([NSDictionary class], @selector(superDescription), @selector(description));
        nu_copyInstanceMethodToSelf([NSSet class], @selector(description), @selector(stringValue));
        nu_copyInstanceMethodToSelf([NSSet class], @selector(superDescription), @selector(description));

        // Copy some useful methods from NSObject to NSProxy.
        // Their implementations are identical; this avoids code duplication.
        transplant_nu_methods([NSProxy class], [NSObject class]);
        
        // swizzle container classes to allow us to add nil to collections (as NSNull).
        nu_swizzleContainerClasses();
    }
}

// Helpers for programmatic construction of Nu code.

id nucstr(const unsigned char *string)
{
    return [NSString stringWithCString:(const char *) string encoding:NSUTF8StringEncoding];
}

id nucstrn(const unsigned char *string, int length)
{
	NSData *data = [NSData dataWithBytes:string length:length];
	return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

id nudata(const void *bytes, int length)
{
	return [NSData dataWithBytes:bytes length:length];
}

id nusymcstr(const unsigned char *cstring)
{
    return [sharedSymbolTable symbolWithString:nucstr(cstring)];
}

id nusymcstrn(const unsigned char *string, int length)
{
	return [[NuSymbolTable sharedSymbolTable] symbolWithString:nucstrn(string, length)];
}

id nudouble(double d)
{
    return [NSNumber numberWithDouble:d];
}

id nucell(id car, id cdr)
{
    return [NuCell cellWithCar:car cdr:cdr];
}

id nuint(int i)
{
    return [NSNumber numberWithInt:i];
}

id nulist(id firstObject, ...)
{
    id list = nil;
    id eachObject;
    va_list argumentList;
    if (firstObject) {
        // The first argument isn't part of the varargs list,
        // so we'll handle it separately.
        list = [[[NuCell alloc] init] autorelease];
        [list setCar:firstObject];
        id cursor = list;
        va_start(argumentList, firstObject);
        // Start scanning for arguments after firstObject.
        // As many times as we can get an argument of type "id"
        // that isn't nil, add it to self's contents.
        while ((eachObject = va_arg(argumentList, id))) {
            [cursor setCdr:[[[NuCell alloc] init] autorelease]];
            cursor = [cursor cdr];
            [cursor setCar:eachObject];
        }
        va_end(argumentList);
    }
    return list;
}

id nuclassname(id obj)
{
    return nucstr(object_getClassName(obj));
}

@implementation Nu
+ (NuParser *) parser
{
    return [[[NuParser alloc] init] autorelease];
}

+ (NuParser *) sharedParser
{
    static NuParser *sharedParser = nil;
    if (!sharedParser) {
        sharedParser = [[NuParser alloc] init];
    }
    return sharedParser;
}

+ (int) sizeOfPointer
{
    return sizeof(void *);
}

@end

#pragma mark - NuBlock.m

@interface NuBlock ()
{
	NuCell *parameters;
    NuCell *body;
	NSMutableDictionary *context;
}
@end

@implementation NuBlock

- (void) dealloc
{
    [parameters release];
    [body release];
    [context release];
    [super dealloc];
}

- (id) initWithParameters:(NuCell *)p body:(NuCell *)b context:(NSMutableDictionary *)c
{
    if ((self = [super init])) {
        parameters = [p retain];
        body = [b retain];
#ifdef CLOSE_ON_VALUES
        context = [c mutableCopy];
#else
        context = [[NSMutableDictionary alloc] init];
        [context setPossiblyNullObject:c forKey:PARENT_KEY];
        [context setPossiblyNullObject:[c objectForKey:SYMBOLS_KEY] forKey:SYMBOLS_KEY];
#endif
        
        // Check for the presence of "*args" in parameter list
        id plist = parameters;
        
        if (!(   ([parameters length] == 1)
              && ([[[parameters car] stringValue] isEqualToString:@"*args"])))
        {
            while (plist && (plist != Nu__null))
            {
                id parameter = [plist car];
                
                if ([[parameter stringValue] isEqualToString:@"*args"])
                {
                    printf("Warning: Overriding implicit variable '*args'.\n");
                    return self;
                }
                
                plist = [plist cdr];
            }
        }
    }
    return self;
}

- (NSString *) stringValue
{
    return [NSString stringWithFormat:@"%@ (fn %@ %@)", [context stringValue], [parameters stringValue], [body stringValue]];
}

- (id)partialEvaluation:(id)cdr context:(NSMutableDictionary *)calling_context
{
    id params_head = nil, params_tail = nil;
    id args_head = nil, args_tail = nil;
    id params_cursor = parameters;
    id args_cursor = cdr;
    while (params_cursor && (params_cursor != Nu__null)
           && args_cursor && (args_cursor != Nu__null))
    {
        params_tail = nucons1(params_tail, [params_cursor car]);
        if (!params_head)
            params_head = params_tail;
        params_cursor = [params_cursor cdr];
        args_tail = nucons1(args_tail, [args_cursor car]);
        if (!args_head)
            args_head = args_tail;
        args_cursor = [args_cursor cdr];
    }
    if (!params_head || !args_head) {
        return self;
    }
    id body_head = nil, body_tail = nil;
    body_head = body_tail = nucons1(body_tail, [[[Nu_fn_operator alloc] init] autorelease]);
    body_tail = nucons1(body_tail, params_cursor);
    [body_tail setCdr:body];
    NuBlock *block = [[NuBlock alloc] initWithParameters:params_head body:nucons1(nil, body_head) context:context];
    id result = [[block evalWithArguments:args_head context:calling_context] retain];
    [block release];
    return [result autorelease];

}

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)calling_context
{
    NSUInteger numberOfArguments = [cdr length];
    NSUInteger numberOfParameters = [parameters length];
    
    if (numberOfArguments != numberOfParameters) {
        // is the last parameter a variable argument? if so, it's ok, and we allow it to have zero elements.
        id lastParameter = [parameters lastObject];
        if (lastParameter && ([[lastParameter stringValue] characterAtIndex:0] == '*')) {
            if (numberOfArguments < (numberOfParameters - 1)) {
                return [self partialEvaluation:cdr context:calling_context];
            }
        }
        else {
            if (numberOfArguments < numberOfParameters) {
                return [self partialEvaluation:cdr context:calling_context];
            }
            [NSException raise:@"NuIncorrectNumberOfArguments"
                        format:@"Incorrect number of arguments to block. Received %d but expected %d: %@",
             numberOfArguments,
             numberOfParameters,
             [parameters stringValue]];
        }
    }
    //NSLog(@"block eval %@", [cdr stringValue]);
    // loop over the parameters, looking up their values in the calling_context and copying them into the evaluation_context
    id plist = parameters;
    id vlist = cdr;
    id evaluation_context = [context mutableCopy];
    
	// Insert the implicit variable "*args".  It contains the entire parameter list.
	NuSymbolTable *symbolTable = [evaluation_context objectForKey:SYMBOLS_KEY];
    [evaluation_context setPossiblyNullObject:cdr forKey:[symbolTable symbolWithString:@"*args"]];
                                                                             
    while (plist && (plist != Nu__null)) {
        id parameter = [plist car];
        if ([[parameter stringValue] characterAtIndex:0] == '*') {
            id varargs = [[[NuCell alloc] init] autorelease];
            id cursor = varargs;
            while (vlist != Nu__null) {
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                id value = [vlist car];
                if (calling_context && (calling_context != Nu__null))
                    value = [value evalWithContext:calling_context];
                [cursor setCar:value];
                vlist = [vlist cdr];
            }
            [evaluation_context setPossiblyNullObject:[varargs cdr] forKey:parameter];
            plist = [plist cdr];
            // this must be the last element in the parameter list
            if (plist != Nu__null) {
                [NSException raise:@"NuBadParameterList"
                            format:@"Variable argument list must be the last parameter in the parameter list: %@",
                 [parameters stringValue]];
            }
        }
        else {
            id value = [vlist car];
            if (calling_context && (calling_context != Nu__null))
                value = [value evalWithContext:calling_context];
            //NSLog(@"setting %@ = %@", parameter, value);
            [evaluation_context setPossiblyNullObject:value forKey:parameter];
            plist = [plist cdr];
            vlist = [vlist cdr];
        }
    }
    // evaluate the body of the block with the saved context (implicit progn)
    id value = Nu__null;
    id cursor = body;
    @try
    {
        while (cursor && (cursor != Nu__null)) {
            value = [[cursor car] evalWithContext:evaluation_context];
            cursor = [cursor cdr];
        }
    }
    @catch (NuReturnException *exception) {
        value = [exception value];
		if ([exception blockForReturn] && ([exception blockForReturn] != self)) {
			@throw(exception);
		}
    }
    @catch (id exception) {
        @throw(exception);
    }
    [value retain];
    [value autorelease];
    [evaluation_context release];
    return value;
}

- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)calling_context
{
    return [self callWithArguments:cdr context:calling_context];
}

- (id) evalWithArguments:(id)cdr
{
    return [self callWithArguments:cdr context:[[Nu sharedParser] context]];
}

id getObjectFromContext(id context, id symbol)
{
    while (IS_NOT_NULL(context)) {
        id object = [context objectForKey:symbol];
        if (object)
            return object;
        context = [context objectForKey:PARENT_KEY];
    }
    return nil;
}

- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)calling_context self:(id)object
{
    NSUInteger numberOfArguments = [cdr length];
    NSUInteger numberOfParameters = [parameters length];
    if (numberOfArguments != numberOfParameters) {
        [NSException raise:@"NuIncorrectNumberOfArguments"
                    format:@"Incorrect number of arguments to method. Received %d but expected %d, %@",
         numberOfArguments,
         numberOfParameters,
         [parameters stringValue]];
    }
    //    NSLog(@"block eval %@", [cdr stringValue]);
    // loop over the arguments, looking up their values in the calling_context and copying them into the evaluation_context
    id plist = parameters;
    id vlist = cdr;
    id evaluation_context = [context mutableCopy];
    //    NSLog(@"after copying, evaluation context %@ retain count %d", evaluation_context, [evaluation_context retainCount]);
    if (object) {
        NuSymbolTable *symbolTable = [evaluation_context objectForKey:SYMBOLS_KEY];
        // look up one level for the _class value, but allow for it to be higher (in the perverse case of nested method declarations).
        NuClass *c = getObjectFromContext([context objectForKey:PARENT_KEY], [symbolTable symbolWithString:@"_class"]);
        [evaluation_context setPossiblyNullObject:object forKey:[symbolTable symbolWithString:@"self"]];
        [evaluation_context setPossiblyNullObject:[NuSuper superWithObject:object ofClass:[c wrappedClass]] forKey:[symbolTable symbolWithString:@"super"]];
    }
    while (plist && (plist != Nu__null) && vlist && (vlist != Nu__null)) {
        id arg = [plist car];
        // since this message is sent by a method handler (which has already evaluated the block arguments),
        // we don't evaluate them here; instead we just copy them
        id value = [vlist car];
        //        NSLog(@"setting %@ = %@", arg, value);
        [evaluation_context setPossiblyNullObject:value forKey:arg];
        plist = [plist cdr];
        vlist = [vlist cdr];
    }
    // evaluate the body of the block with the saved context (implicit progn)
    id value = Nu__null;
    id cursor = body;
    @try
    {
        while (cursor && (cursor != Nu__null)) {
            value = [[cursor car] evalWithContext:evaluation_context];
            cursor = [cursor cdr];
        }
    }
    @catch (NuReturnException *exception) {
        value = [exception value];
		if ([exception blockForReturn] && ([exception blockForReturn] != self)) {
			@throw(exception);
		}
    }
    @catch (id exception) {
        @throw(exception);
    }
    [value retain];
    [value autorelease];
    [evaluation_context release];
    return value;
}

- (NSMutableDictionary *) context
{
    return context;
}

- (NuCell *) parameters
{
    return parameters;
}

- (NuCell *) body
{
    return body;
}

- (void)setTableViewStyle:(int)n
{
    prn([NSString stringWithFormat:@"setTableViewStyle %@", [self stringValue]]);
}
@end

@implementation NuImp
@synthesize block = _block;
@synthesize methodSignature = _methodSignature;

- (void)dealloc
{
    self.block = nil;
    self.methodSignature = nil;
    [super dealloc];
}

- (id)initWithBlock:(NuBlock *)block signature:(const char *)signature
{
    self = [super init];
    if (self) {
        self.block = block;
        self.methodSignature = [NSMethodSignature signatureWithObjCTypes:signature];
    }
    return self;
}

@end


#pragma mark - NuBridge.m

/*
 * types:
 * c char
 * i int
 * s short
 * l long
 * q long long
 * C unsigned char
 * I unsigned int
 * S unsigned short
 * L unsigned long
 * Q unsigned long long
 * f float
 * d double
 * B bool (c++)
 * v void
 * * char *
 * @ id
 * # Class
 * : SEL
 * ? unknown
 * b4             bit field of 4 bits
 * ^type          pointer to type
 * [type]         array
 * {name=type...} structure
 * (name=type...) union
 *
 * modifiers:
 * r const
 * n in
 * N inout
 * o out
 * O bycopy
 * R byref
 * V oneway
 */

NSMutableDictionary *nu_block_table = nil;

#ifdef __x86_64__

#define NSRECT_SIGNATURE0 "{_NSRect={_NSPoint=dd}{_NSSize=dd}}"
#define NSRECT_SIGNATURE1 "{_NSRect=\"origin\"{_NSPoint=\"x\"d\"y\"d}\"size\"{_NSSize=\"width\"d\"height\"d}}"
#define NSRECT_SIGNATURE2 "{_NSRect}"

#define CGRECT_SIGNATURE0 "{CGRect={CGPoint=dd}{CGSize=dd}}"
#define CGRECT_SIGNATURE1 "{CGRect=\"origin\"{CGPoint=\"x\"d\"y\"d}\"size\"{CGSize=\"width\"d\"height\"d}}"
#define CGRECT_SIGNATURE2 "{CGRect}"

#define NSRANGE_SIGNATURE "{_NSRange=QQ}"
#define NSRANGE_SIGNATURE1 "{_NSRange}"

#define NSPOINT_SIGNATURE0 "{_NSPoint=dd}"
#define NSPOINT_SIGNATURE1 "{_NSPoint=\"x\"d\"y\"d}"
#define NSPOINT_SIGNATURE2 "{_NSPoint}"

#define CGPOINT_SIGNATURE "{CGPoint=dd}"

#define NSSIZE_SIGNATURE0 "{_NSSize=dd}"
#define NSSIZE_SIGNATURE1 "{_NSSize=\"width\"d\"height\"d}"
#define NSSIZE_SIGNATURE2 "{_NSSize}"

#define CGSIZE_SIGNATURE "{CGSize=dd}"

#else

#define NSRECT_SIGNATURE0 "{_NSRect={_NSPoint=ff}{_NSSize=ff}}"
#define NSRECT_SIGNATURE1 "{_NSRect=\"origin\"{_NSPoint=\"x\"f\"y\"f}\"size\"{_NSSize=\"width\"f\"height\"f}}"
#define NSRECT_SIGNATURE2 "{_NSRect}"

#define CGRECT_SIGNATURE0 "{CGRect={CGPoint=ff}{CGSize=ff}}"
#define CGRECT_SIGNATURE1 "{CGRect=\"origin\"{CGPoint=\"x\"f\"y\"f}\"size\"{CGSize=\"width\"f\"height\"f}}"
#define CGRECT_SIGNATURE2 "{CGRect}"

#define NSRANGE_SIGNATURE "{_NSRange=II}"
#define NSRANGE_SIGNATURE1 "{_NSRange}"

#define NSPOINT_SIGNATURE0 "{_NSPoint=ff}"
#define NSPOINT_SIGNATURE1 "{_NSPoint=\"x\"f\"y\"f}"
#define NSPOINT_SIGNATURE2 "{_NSPoint}"

#define CGPOINT_SIGNATURE "{CGPoint=ff}"

#define NSSIZE_SIGNATURE0 "{_NSSize=ff}"
#define NSSIZE_SIGNATURE1 "{_NSSize=\"width\"f\"height\"f}"
#define NSSIZE_SIGNATURE2 "{_NSSize}"

#define CGSIZE_SIGNATURE "{CGSize=ff}"
#endif
#define CLLOCATIONCOORDINATE2D_SIGNATURE "{?=dd}"
#define MKCOORDINATEREGION_SIGNATURE "{?={?=dd}{?=dd}}"
#define FFI_FF_SIGNATURE "{?=ff}"
#define FFI_FFFF_SIGNATURE "{?=ffff}"
#define FFI_CPBB_SIGNATURE "{cpBB=ffff}"
#define CCCOLOR3B_SIGNATURE "{_ccColor3B=CCC}"
#define CGAFFINETRANSFORM_SIGNATURE "{CGAffineTransform=ffffff}"

// private ffi types
int initialized_ffi_types = false;
ffi_type ffi_type_nspoint;
ffi_type ffi_type_nssize;
ffi_type ffi_type_nsrect;
ffi_type ffi_type_nsrange;
ffi_type ffi_type_cccolor3b;
ffi_type ffi_type_cllocationcoordinate2d;
ffi_type ffi_type_mkcoordinateregion;
ffi_type ffi_type_ff;
ffi_type ffi_type_ffff;
ffi_type ffi_type_cgaffinetransform;

void initialize_ffi_types(void)
{
    if (initialized_ffi_types) return;
    initialized_ffi_types = true;
    
    // It would be better to do this automatically by parsing the ObjC type signatures
    ffi_type_nspoint.size = 0;                    // to be computed automatically
    ffi_type_nspoint.alignment = 0;
    ffi_type_nspoint.type = FFI_TYPE_STRUCT;
    ffi_type_nspoint.elements = malloc(3 * sizeof(ffi_type*));
#ifdef __x86_64__
    ffi_type_nspoint.elements[0] = &ffi_type_double;
    ffi_type_nspoint.elements[1] = &ffi_type_double;
#else
    ffi_type_nspoint.elements[0] = &ffi_type_float;
    ffi_type_nspoint.elements[1] = &ffi_type_float;
#endif
    ffi_type_nspoint.elements[2] = NULL;
    
    ffi_type_nssize.size = 0;                     // to be computed automatically
    ffi_type_nssize.alignment = 0;
    ffi_type_nssize.type = FFI_TYPE_STRUCT;
    ffi_type_nssize.elements = malloc(3 * sizeof(ffi_type*));
#ifdef __x86_64__
    ffi_type_nssize.elements[0] = &ffi_type_double;
    ffi_type_nssize.elements[1] = &ffi_type_double;
#else
    ffi_type_nssize.elements[0] = &ffi_type_float;
    ffi_type_nssize.elements[1] = &ffi_type_float;
#endif
    ffi_type_nssize.elements[2] = NULL;
    
    ffi_type_nsrect.size = 0;                     // to be computed automatically
    ffi_type_nsrect.alignment = 0;
    ffi_type_nsrect.type = FFI_TYPE_STRUCT;
    ffi_type_nsrect.elements = malloc(3 * sizeof(ffi_type*));
    ffi_type_nsrect.elements[0] = &ffi_type_nspoint;
    ffi_type_nsrect.elements[1] = &ffi_type_nssize;
    ffi_type_nsrect.elements[2] = NULL;
    
    ffi_type_nsrange.size = 0;                    // to be computed automatically
    ffi_type_nsrange.alignment = 0;
    ffi_type_nsrange.type = FFI_TYPE_STRUCT;
    ffi_type_nsrange.elements = malloc(3 * sizeof(ffi_type*));
#ifdef __x86_64__
    ffi_type_nsrange.elements[0] = &ffi_type_uint64;
    ffi_type_nsrange.elements[1] = &ffi_type_uint64;
#else
    ffi_type_nsrange.elements[0] = &ffi_type_uint;
    ffi_type_nsrange.elements[1] = &ffi_type_uint;
#endif
    ffi_type_nsrange.elements[2] = NULL;
    ffi_type_cccolor3b.size = 0;
    ffi_type_cccolor3b.alignment = 0;
    ffi_type_cccolor3b.type = FFI_TYPE_STRUCT;
    ffi_type_cccolor3b.elements = malloc(4 * sizeof(ffi_type*));
    ffi_type_cccolor3b.elements[0] = &ffi_type_uchar;
    ffi_type_cccolor3b.elements[1] = &ffi_type_uchar;
    ffi_type_cccolor3b.elements[2] = &ffi_type_uchar;
    ffi_type_cccolor3b.elements[3] = NULL;
    ffi_type_cllocationcoordinate2d.size = 0;
    ffi_type_cllocationcoordinate2d.alignment = 0;
    ffi_type_cllocationcoordinate2d.type = FFI_TYPE_STRUCT;
    ffi_type_cllocationcoordinate2d.elements = malloc(3 * sizeof(ffi_type*));
    ffi_type_cllocationcoordinate2d.elements[0] = &ffi_type_double;
    ffi_type_cllocationcoordinate2d.elements[1] = &ffi_type_double;
    ffi_type_cllocationcoordinate2d.elements[2] = NULL;
    ffi_type_mkcoordinateregion.size = 0;
    ffi_type_mkcoordinateregion.alignment = 0;
    ffi_type_mkcoordinateregion.type = FFI_TYPE_STRUCT;
    ffi_type_mkcoordinateregion.elements = malloc(5 * sizeof(ffi_type*));
    ffi_type_mkcoordinateregion.elements[0] = &ffi_type_double;
    ffi_type_mkcoordinateregion.elements[1] = &ffi_type_double;
    ffi_type_mkcoordinateregion.elements[2] = &ffi_type_double;
    ffi_type_mkcoordinateregion.elements[3] = &ffi_type_double;
    ffi_type_mkcoordinateregion.elements[4] = NULL;
    ffi_type_ff.size = 0;
    ffi_type_ff.alignment = 0;
    ffi_type_ff.type = FFI_TYPE_STRUCT;
    ffi_type_ff.elements = malloc(3 * sizeof(ffi_type*));
    ffi_type_ff.elements[0] = &ffi_type_float;
    ffi_type_ff.elements[1] = &ffi_type_float;
    ffi_type_ff.elements[2] = NULL;
    ffi_type_ffff.size = 0;
    ffi_type_ffff.alignment = 0;
    ffi_type_ffff.type = FFI_TYPE_STRUCT;
    ffi_type_ffff.elements = malloc(5 * sizeof(ffi_type*));
    ffi_type_ffff.elements[0] = &ffi_type_float;
    ffi_type_ffff.elements[1] = &ffi_type_float;
    ffi_type_ffff.elements[2] = &ffi_type_float;
    ffi_type_ffff.elements[3] = &ffi_type_float;
    ffi_type_ffff.elements[4] = NULL;
    ffi_type_cgaffinetransform.size = 0;
    ffi_type_cgaffinetransform.alignment = 0;
    ffi_type_cgaffinetransform.type = FFI_TYPE_STRUCT;
    ffi_type_cgaffinetransform.elements = malloc(7 * sizeof(ffi_type *));
    ffi_type_cgaffinetransform.elements[0] = &ffi_type_float;
    ffi_type_cgaffinetransform.elements[1] = &ffi_type_float;
    ffi_type_cgaffinetransform.elements[2] = &ffi_type_float;
    ffi_type_cgaffinetransform.elements[3] = &ffi_type_float;
    ffi_type_cgaffinetransform.elements[4] = &ffi_type_float;
    ffi_type_cgaffinetransform.elements[5] = &ffi_type_float;
    ffi_type_cgaffinetransform.elements[6] = NULL;
}

char get_typeChar_from_typeString(const char *typeString)
{
    int i = 0;
    char typeChar = typeString[i];
    while ((typeChar == 'r') || (typeChar == 'R') ||
           (typeChar == 'n') || (typeChar == 'N') ||
           (typeChar == 'o') || (typeChar == 'O') ||
           (typeChar == 'V')
           ) {
        // uncomment the following two lines to complain about unused quantifiers in ObjC type encodings
        // if (typeChar != 'r')                      // don't worry about const
        //     NSLog(@"ignoring qualifier %c in %s", typeChar, typeString);
        typeChar = typeString[++i];
    }
    return typeChar;
}

ffi_type *ffi_type_for_objc_type(const char *typeString)
{
    char typeChar = get_typeChar_from_typeString(typeString);
    switch (typeChar) {
        case 'f': return &ffi_type_float;
        case 'd': return &ffi_type_double;
        case 'v': return &ffi_type_void;
        case 'B': return &ffi_type_uchar;
        case 'C': return &ffi_type_uchar;
        case 'c': return &ffi_type_schar;
        case 'S': return &ffi_type_ushort;
        case 's': return &ffi_type_sshort;
        case 'I': return &ffi_type_uint;
        case 'i': return &ffi_type_sint;
#ifdef __x86_64__
        case 'L': return &ffi_type_ulong;
        case 'l': return &ffi_type_slong;
#else
        case 'L': return &ffi_type_uint;
        case 'l': return &ffi_type_sint;
#endif
        case 'Q': return &ffi_type_uint64;
        case 'q': return &ffi_type_sint64;
        case '@': return &ffi_type_pointer;
        case '#': return &ffi_type_pointer;
        case '*': return &ffi_type_pointer;
        case ':': return &ffi_type_pointer;
        case '^': return &ffi_type_pointer;
        case '{':
        {
            if (!strcmp(typeString, NSRECT_SIGNATURE0) ||
                !strcmp(typeString, NSRECT_SIGNATURE1) ||
                !strcmp(typeString, NSRECT_SIGNATURE2) ||
                !strcmp(typeString, CGRECT_SIGNATURE0) ||
                !strcmp(typeString, CGRECT_SIGNATURE1) ||
                !strcmp(typeString, CGRECT_SIGNATURE2)
                ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nsrect;
            }
            else if (
                     !strcmp(typeString, NSRANGE_SIGNATURE) ||
                     !strcmp(typeString, NSRANGE_SIGNATURE1)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nsrange;
            }
            else if (
                     !strcmp(typeString, NSPOINT_SIGNATURE0) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE1) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE2) ||
                     !strcmp(typeString, CGPOINT_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nspoint;
            }
            else if (
                     !strcmp(typeString, NSSIZE_SIGNATURE0) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE1) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE2) ||
                     !strcmp(typeString, CGSIZE_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_nssize;
            }
            else if (
                     !strcmp(typeString, CCCOLOR3B_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_cccolor3b;
            }
            else if (
                     !strcmp(typeString, CLLOCATIONCOORDINATE2D_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_cllocationcoordinate2d;
            }
            else if (
                     !strcmp(typeString, MKCOORDINATEREGION_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_mkcoordinateregion;
            }
            else if (
                     !strcmp(typeString, FFI_FF_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_ff;
            }
            else if (
                     !strcmp(typeString, FFI_FFFF_SIGNATURE) ||
                     !strcmp(typeString, FFI_CPBB_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_ffff;
            }
            else if (
                     !strcmp(typeString, CGAFFINETRANSFORM_SIGNATURE)
                     ) {
                if (!initialized_ffi_types) initialize_ffi_types();
                return &ffi_type_cgaffinetransform;
            }
            else {
                NSLog(@"unknown type identifier %s", typeString);
                return &ffi_type_void;
            }
        }
        default:
        {
            NSLog(@"unknown type identifier %s", typeString);
            return &ffi_type_void;                // urfkd
        }
    }
}

size_t size_of_objc_type(const char *typeString)
{
    char typeChar = get_typeChar_from_typeString(typeString);
    switch (typeChar) {
        case 'f': return sizeof(float);
        case 'd': return sizeof(double);
        case 'v': return sizeof(void *);
        case 'B': return sizeof(unsigned int);
        case 'C': return sizeof(unsigned int);
        case 'c': return sizeof(int);
        case 'S': return sizeof(unsigned int);
        case 's': return sizeof(int);
        case 'I': return sizeof(unsigned int);
        case 'i': return sizeof(int);
        case 'L': return sizeof(unsigned long);
        case 'l': return sizeof(long);
        case 'Q': return sizeof(unsigned long long);
        case 'q': return sizeof(long long);
        case '@': return sizeof(void *);
        case '#': return sizeof(void *);
        case '*': return sizeof(void *);
        case ':': return sizeof(void *);
        case '^': return sizeof(void *);
        case '{':
        {
            if (!strcmp(typeString, NSRECT_SIGNATURE0) ||
                !strcmp(typeString, NSRECT_SIGNATURE1) ||
                !strcmp(typeString, NSRECT_SIGNATURE2) ||
                !strcmp(typeString, CGRECT_SIGNATURE0) ||
                !strcmp(typeString, CGRECT_SIGNATURE1) ||
                !strcmp(typeString, CGRECT_SIGNATURE2)
                ) {
                return sizeof(NSRect);
            }
            else if (
                     !strcmp(typeString, NSRANGE_SIGNATURE) ||
                     !strcmp(typeString, NSRANGE_SIGNATURE1)
                     ) {
                return sizeof(NSRange);
            }
            else if (
                     !strcmp(typeString, NSPOINT_SIGNATURE0) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE1) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE2) ||
                     !strcmp(typeString, CGPOINT_SIGNATURE)
                     ) {
                return sizeof(NSPoint);
            }
            else if (
                     !strcmp(typeString, NSSIZE_SIGNATURE0) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE1) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE2) ||
                     !strcmp(typeString, CGSIZE_SIGNATURE)
                     ) {
                return sizeof(NSSize);
            }
#ifdef NU_CCTYPES
            else if (
                     !strcmp(typeString, CCCOLOR3B_SIGNATURE)
                     ) {
                return sizeof(ccColor3B);
            }
#endif
            else if (
                     !strcmp(typeString, CLLOCATIONCOORDINATE2D_SIGNATURE)
                     ) {
                return sizeof(CLLocationCoordinate2D);
            }
            else if (
                     !strcmp(typeString, MKCOORDINATEREGION_SIGNATURE)
                     ) {
                return sizeof(MKCoordinateRegion);
            }
            else if (
                     !strcmp(typeString, FFI_FF_SIGNATURE)
                     ) {
                return sizeof(float)*2;
            }
            else if (
                     !strcmp(typeString, FFI_FFFF_SIGNATURE) ||
                     !strcmp(typeString, FFI_CPBB_SIGNATURE)
                     ) {
                return sizeof(float)*4;
            }
            else if (
                     !strcmp(typeString, CGAFFINETRANSFORM_SIGNATURE)
                     ) {
                return sizeof(float)*6;
            }
            else {
                NSLog(@"unknown type identifier %s", typeString);
                return sizeof (void *);
            }
        }
        default:
        {
            NSLog(@"unknown type identifier %s", typeString);
            return sizeof (void *);
        }
    }
}

void *value_buffer_for_objc_type(const char *typeString)
{
    char typeChar = get_typeChar_from_typeString(typeString);
    switch (typeChar) {
        case 'f': return malloc(sizeof(float));
        case 'd': return malloc(sizeof(double));
        case 'v': return malloc(sizeof(void *));
        case 'B': return malloc(sizeof(unsigned int));
        case 'C': return malloc(sizeof(unsigned int));
        case 'c': return malloc(sizeof(int));
        case 'S': return malloc(sizeof(unsigned int));
        case 's': return malloc(sizeof(int));
        case 'I': return malloc(sizeof(unsigned int));
        case 'i': return malloc(sizeof(int));
        case 'L': return malloc(sizeof(unsigned long));
        case 'l': return malloc(sizeof(long));
        case 'Q': return malloc(sizeof(unsigned long long));
        case 'q': return malloc(sizeof(long long));
        case '@': return malloc(sizeof(void *));
        case '#': return malloc(sizeof(void *));
        case '*': return malloc(sizeof(void *));
        case ':': return malloc(sizeof(void *));
        case '^': return malloc(sizeof(void *));
        case '{':
        {
            if (!strcmp(typeString, NSRECT_SIGNATURE0) ||
                !strcmp(typeString, NSRECT_SIGNATURE1) ||
                !strcmp(typeString, NSRECT_SIGNATURE2) ||
                !strcmp(typeString, CGRECT_SIGNATURE0) ||
                !strcmp(typeString, CGRECT_SIGNATURE1) ||
                !strcmp(typeString, CGRECT_SIGNATURE2)
                ) {
                return malloc(sizeof(NSRect));
            }
            else if (
                     !strcmp(typeString, NSRANGE_SIGNATURE) ||
                     !strcmp(typeString, NSRANGE_SIGNATURE1)
                     ) {
                return malloc(sizeof(NSRange));
            }
            else if (
                     !strcmp(typeString, NSPOINT_SIGNATURE0) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE1) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE2) ||
                     !strcmp(typeString, CGPOINT_SIGNATURE)
                     ) {
                return malloc(sizeof(NSPoint));
            }
            else if (
                     !strcmp(typeString, NSSIZE_SIGNATURE0) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE1) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE2) ||
                     !strcmp(typeString, CGSIZE_SIGNATURE)
                     ) {
                return malloc(sizeof(NSSize));
            }
#ifdef NU_CCTYPES
            else if (
                     !strcmp(typeString, CCCOLOR3B_SIGNATURE)
                     ) {
                return malloc(sizeof(ccColor3B));
            }
#endif
            else if (
                     !strcmp(typeString, CLLOCATIONCOORDINATE2D_SIGNATURE)
                     ) {
                return malloc(sizeof(CLLocationCoordinate2D));
            }
            else if (
                     !strcmp(typeString, MKCOORDINATEREGION_SIGNATURE)
                     ) {
                return malloc(sizeof(MKCoordinateRegion));
            }
            else if (
                     !strcmp(typeString, FFI_FF_SIGNATURE)
                     ) {
                return malloc(sizeof(float)*2);
            }
            else if (
                     !strcmp(typeString, FFI_FFFF_SIGNATURE) ||
                     !strcmp(typeString, FFI_CPBB_SIGNATURE)
                     ) {
                return malloc(sizeof(float)*4);
            }
            else if (
                     !strcmp(typeString, CGAFFINETRANSFORM_SIGNATURE)
                     ) {
                return malloc(sizeof(float)*6);
            }
            else {
                NSLog(@"unknown type identifier %s", typeString);
                return malloc(sizeof (void *));
            }
        }
        default:
        {
            NSLog(@"unknown type identifier %s", typeString);
            return malloc(sizeof (void *));
        }
    }
}

int set_objc_value_from_nu_value(void *objc_value, id nu_value, const char *typeString)
{
    //NSLog(@"VALUE => %s", typeString);
    char typeChar = get_typeChar_from_typeString(typeString);
    switch (typeChar) {
        case '@':
        {
            if (nu_value == Nu__null) {
                *((id *) objc_value) = nil;
                return NO;
            }
            *((id *) objc_value) = nu_value;
            return NO;
        }
        case 'I':
#ifndef __ppc__
        case 'S':
        case 'C':
#endif
        {
            if (nu_value == Nu__null) {
                *((unsigned int *) objc_value) = 0;
                return NO;
            }
            *((unsigned int *) objc_value) = [nu_value unsignedIntValue];
            return NO;
        }
#ifdef __ppc__
        case 'S':
        {
            if (nu_value == Nu__null) {
                *((unsigned short *) objc_value) = 0;
                return NO;
            }
            *((unsigned short *) objc_value) = [nu_value unsignedShortValue];
            return NO;
        }
        case 'C':
        {
            if (nu_value == Nu__null) {
                *((unsigned char *) objc_value) = 0;
                return NO;
            }
            *((unsigned char *) objc_value) = [nu_value unsignedCharValue];
            return NO;
        }
#endif
        case 'i':
#ifndef __ppc__
        case 's':
        case 'c':
#endif
        {
            if (nu_value == [NSNull null]) {
                *((int *) objc_value) = 0;
                return NO;
            }
            *((int *) objc_value) = [nu_value intValue];
            return NO;
        }
#ifdef __ppc__
        case 's':
        {
            if (nu_value == Nu__null) {
                *((short *) objc_value) = 0;
                return NO;
            }
            *((short *) objc_value) = [nu_value shortValue];
            return NO;
        }
        case 'c':
        {
            if (nu_value == Nu__null) {
                *((char *) objc_value) = 0;
                return NO;
            }
            *((char *) objc_value) = [nu_value charValue];
            return NO;
        }
#endif
        case 'L':
        {
            if (nu_value == [NSNull null]) {
                *((unsigned long *) objc_value) = 0;
                return NO;
            }
            *((unsigned long *) objc_value) = [nu_value unsignedLongValue];
            return NO;
        }
        case 'l':
        {
            if (nu_value == [NSNull null]) {
                *((long *) objc_value) = 0;
                return NO;
            }
            *((long *) objc_value) = [nu_value longValue];
            return NO;
        }
        case 'Q':
        {
            if (nu_value == [NSNull null]) {
                *((unsigned long long *) objc_value) = 0;
                return NO;
            }
            *((unsigned long long *) objc_value) = [nu_value unsignedLongLongValue];
            return NO;
        }
        case 'q':
        {
            if (nu_value == [NSNull null]) {
                *((long long *) objc_value) = 0;
                return NO;
            }
            *((long long *) objc_value) = [nu_value longLongValue];
            return NO;
        }
        case 'd':
        {
            *((double *) objc_value) = [nu_value doubleValue];
            return NO;
        }
        case 'f':
        {
            *((float *) objc_value) = (float) [nu_value doubleValue];
            return NO;
        }
        case 'v':
        {
            return NO;
        }
        case ':':
        {
            // selectors must be strings (symbols could be ok too...)
            if (!nu_value || (nu_value == [NSNull null])) {
                *((SEL *) objc_value) = 0;
                return NO;
            }
            const char *selectorName = [nu_value cStringUsingEncoding:NSUTF8StringEncoding];
            if (selectorName) {
                *((SEL *) objc_value) = sel_registerName(selectorName);
                return NO;
            }
            else {
                NSLog(@"can't convert %@ to a selector", nu_value);
                return NO;
            }
        }
        case '{':
        {
            if (
                !strcmp(typeString, NSRECT_SIGNATURE0) ||
                !strcmp(typeString, NSRECT_SIGNATURE1) ||
                !strcmp(typeString, NSRECT_SIGNATURE2) ||
                !strcmp(typeString, CGRECT_SIGNATURE0) ||
                !strcmp(typeString, CGRECT_SIGNATURE1) ||
                !strcmp(typeString, CGRECT_SIGNATURE2)
                ) {
                NSRect *rect = (NSRect *) objc_value;
                id cursor = nu_value;
                rect->origin.x = (CGFloat) [[cursor car] doubleValue];            cursor = [cursor cdr];
                rect->origin.y = (CGFloat) [[cursor car] doubleValue];            cursor = [cursor cdr];
                rect->size.width = (CGFloat) [[cursor car] doubleValue];          cursor = [cursor cdr];
                rect->size.height = (CGFloat) [[cursor car] doubleValue];
                //NSLog(@"nu->rect: %x %f %f %f %f", (void *) rect, rect->origin.x, rect->origin.y, rect->size.width, rect->size.height);
                return NO;
            }
            else if (
                     !strcmp(typeString, NSRANGE_SIGNATURE) ||
                     !strcmp(typeString, NSRANGE_SIGNATURE1)
                     ) {
                NSRange *range = (NSRange *) objc_value;
                id cursor = nu_value;
                range->location = [[cursor car] intValue];          cursor = [cursor cdr];;
                range->length = [[cursor car] intValue];
                return NO;
            }
            else if (
                     !strcmp(typeString, NSSIZE_SIGNATURE0) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE1) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE2) ||
                     !strcmp(typeString, CGSIZE_SIGNATURE)
                     ) {
                NSSize *size = (NSSize *) objc_value;
                id cursor = nu_value;
                size->width = [[cursor car] doubleValue];           cursor = [cursor cdr];;
                size->height =  [[cursor car] doubleValue];
                return NO;
            }
            else if (
                     !strcmp(typeString, NSPOINT_SIGNATURE0) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE1) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE2) ||
                     !strcmp(typeString, CGPOINT_SIGNATURE)
                     ) {
                NSPoint *point = (NSPoint *) objc_value;
                id cursor = nu_value;
                point->x = [[cursor car] doubleValue];          cursor = [cursor cdr];;
                point->y =  [[cursor car] doubleValue];
                return NO;
            }
#ifdef NU_CCTYPES
            else if (
                     !strcmp(typeString, CCCOLOR3B_SIGNATURE)
                     ) {
                ccColor3B *color = (ccColor3B *) objc_value;
                id cursor = nu_value;
                color->r = [[cursor car] unsignedCharValue];    cursor = [cursor cdr];;
                color->g = [[cursor car] unsignedCharValue];    cursor = [cursor cdr];;
                color->b = [[cursor car] unsignedCharValue];
                return NO;
            }
#endif
            else if (
                     !strcmp(typeString, CLLOCATIONCOORDINATE2D_SIGNATURE)
                     ) {
                CLLocationCoordinate2D *loc = (CLLocationCoordinate2D *) objc_value;
                id cursor = nu_value;
                loc->latitude = [[cursor car] doubleValue];     cursor = [cursor cdr];;
                loc->longitude = [[cursor car] doubleValue];
                return NO;
            }
            else if (
                     !strcmp(typeString, MKCOORDINATEREGION_SIGNATURE)
                     ) {
                MKCoordinateRegion *region = (MKCoordinateRegion *) objc_value;
                id cursor = nu_value;
                region->center.latitude = [[cursor car] doubleValue];   cursor = [cursor cdr];;
                region->center.longitude = [[cursor car] doubleValue];  cursor = [cursor cdr];;
                region->span.latitudeDelta = [[cursor car] doubleValue];    cursor = [cursor cdr];;
                region->span.longitudeDelta = [[cursor car] doubleValue];
                return NO;
            }
            else if (
                     !strcmp(typeString, FFI_FF_SIGNATURE)
                     ) {
                float *val = (float *) objc_value;
                id cursor = nu_value;
                val[0] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[1] = [[cursor car] floatValue];
                return NO;
            }
            else if (
                     !strcmp(typeString, FFI_FFFF_SIGNATURE) ||
                     !strcmp(typeString, FFI_CPBB_SIGNATURE)
                     ) {
                float *val = (float *) objc_value;
                id cursor = nu_value;
                val[0] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[1] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[2] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[3] = [[cursor car] floatValue];
                return NO;
            }
            else if (
                     !strcmp(typeString, CGAFFINETRANSFORM_SIGNATURE)
                     ) {
                float *val = (float *) objc_value;
                id cursor = nu_value;
                val[0] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[1] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[2] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[3] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[4] = [[cursor car] floatValue]; cursor = [cursor cdr];;
                val[5] = [[cursor car] floatValue];
                return NO;
            }
            else {
                NSLog(@"UNIMPLEMENTED: can't wrap structure of type %s", typeString);
                return NO;
            }
        }
            
        case '^':
        {
            if (!nu_value || (nu_value == [NSNull null])) {
                *((char ***) objc_value) = NULL;
                return NO;
            }
            // pointers require some work.. and cleanup. This LEAKS.
            if (!strcmp(typeString, "^*")) {
                // array of strings, which requires an NSArray or NSNull (handled above)
                if (nu_objectIsKindOfClass(nu_value, [NSArray class])) {
                    NSUInteger array_size = [nu_value count];
                    char **array = (char **) malloc (array_size * sizeof(char *));
                    int i;
                    for (i = 0; i < array_size; i++) {
                        array[i] = strdup([[nu_value objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding]);
                    }
                    *((char ***) objc_value) = array;
                    return NO;
                }
                else {
                    NSLog(@"can't convert value of type %s to a pointer to strings", class_getName([nu_value class]));
                    *((char ***) objc_value) = NULL;
                    return NO;
                }
            }
            else if (!strcmp(typeString, "^@")) {
                if (nu_objectIsKindOfClass(nu_value, [NuReference class])) {
                    *((id **) objc_value) = [nu_value pointerToReferencedObject];
                    return YES;
                }
            }
            else if (nu_objectIsKindOfClass(nu_value, [NuPointer class])) {
                if ([nu_value pointer] == 0)
                    [nu_value allocateSpaceForTypeString:[NSString stringWithCString:typeString encoding:NSUTF8StringEncoding]];
                *((void **) objc_value) = [nu_value pointer];
                return NO;                        // don't ask the receiver to retain this, it's just a pointer
            }
            else {
                *((void **) objc_value) = nu_value;
                return NO;                        // don't ask the receiver to retain this, it isn't expecting an object
            }
        }
            
        case '*':
        {
            *((char **) objc_value) = (char*)[[nu_value stringValue] cStringUsingEncoding:NSUTF8StringEncoding];
            return NO;
        }
            
        case '#':
        {
            if (nu_objectIsKindOfClass(nu_value, [NuClass class])) {
                *((Class *)objc_value) = [nu_value wrappedClass];
                return NO;
            }
            else {
                NSLog(@"can't convert value of type %s to CLASS", class_getName([nu_value class]));
                *((id *) objc_value) = 0;
                return NO;
            }
        }
        default:
            NSLog(@"can't wrap argument of type %s", typeString);
    }
    return NO;
}

id get_nu_value_from_objc_value(void *objc_value, const char *typeString)
{
    //NSLog(@"%s => VALUE", typeString);
    char typeChar = get_typeChar_from_typeString(typeString);
    switch(typeChar) {
        case 'v':
        {
            return [NSNull null];
        }
        case '@':
        {
            id result = *((id *)objc_value);
            return result ? result : (id)[NSNull null];
        }
        case '#':
        {
            Class c = *((Class *)objc_value);
            return c ? [[NuClass alloc] initWithClass:c] : Nu__null;
        }
#ifndef __ppc__
        case 'c':
        {
            return [NSNumber numberWithChar:*((char *)objc_value)];
        }
        case 's':
        {
            return [NSNumber numberWithShort:*((short *)objc_value)];
        }
#else
        case 'c':
        case 's':
#endif
        case 'i':
        {
            return [NSNumber numberWithInt:*((int *)objc_value)];
        }
#ifndef __ppc__
        case 'C':
        {
            return [NSNumber numberWithUnsignedChar:*((unsigned char *)objc_value)];
        }
        case 'S':
        {
            return [NSNumber numberWithUnsignedShort:*((unsigned short *)objc_value)];
        }
#else
        case 'C':
        case 'S':
#endif
        case 'I':
        {
            return [NSNumber numberWithUnsignedInt:*((unsigned int *)objc_value)];
        }
        case 'l':
        {
            return [NSNumber numberWithLong:*((long *)objc_value)];
        }
        case 'L':
        {
            return [NSNumber numberWithUnsignedLong:*((unsigned long *)objc_value)];
        }
        case 'q':
        {
            return [NSNumber numberWithLongLong:*((long long *)objc_value)];
        }
        case 'Q':
        {
            return [NSNumber numberWithUnsignedLongLong:*((unsigned long long *)objc_value)];
        }
        case 'f':
        {
            return [NSNumber numberWithFloat:*((float *)objc_value)];
        }
        case 'd':
        {
            return [NSNumber numberWithDouble:*((double *)objc_value)];
        }
        case ':':
        {
            SEL sel = *((SEL *)objc_value);
            return [[NSString stringWithCString:sel_getName(sel) encoding:NSUTF8StringEncoding] retain];
        }
        case '{':
        {
            if (
                !strcmp(typeString, NSRECT_SIGNATURE0) ||
                !strcmp(typeString, NSRECT_SIGNATURE1) ||
                !strcmp(typeString, NSRECT_SIGNATURE2) ||
                !strcmp(typeString, CGRECT_SIGNATURE0) ||
                !strcmp(typeString, CGRECT_SIGNATURE1) ||
                !strcmp(typeString, CGRECT_SIGNATURE2)
                ) {
                NSRect *rect = (NSRect *)objc_value;
                NuCell *list = [[[NuCell alloc] init] autorelease];
                id cursor = list;
                [cursor setCar:[NSNumber numberWithDouble:rect->origin.x]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:rect->origin.y]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:rect->size.width]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:rect->size.height]];
                //NSLog(@"converting rect at %x to list: %@", (void *) rect, [list stringValue]);
                return list;
            }
            else if (
                     !strcmp(typeString, NSRANGE_SIGNATURE) ||
                     !strcmp(typeString, NSRANGE_SIGNATURE1)
                     ) {
                NSRange *range = (NSRange *)objc_value;
                NuCell *list = [[[NuCell alloc] init] autorelease];
                id cursor = list;
                [cursor setCar:[NSNumber numberWithInteger:range->location]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithInteger:range->length]];
                return list;
            }
            else if (
                     !strcmp(typeString, NSPOINT_SIGNATURE0) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE1) ||
                     !strcmp(typeString, NSPOINT_SIGNATURE2) ||
                     !strcmp(typeString, CGPOINT_SIGNATURE)
                     ) {
                NSPoint *point = (NSPoint *)objc_value;
                NuCell *list = [[[NuCell alloc] init] autorelease];
                id cursor = list;
                [cursor setCar:[NSNumber numberWithDouble:point->x]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:point->y]];
                return list;
            }
            else if (
                     !strcmp(typeString, NSSIZE_SIGNATURE0) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE1) ||
                     !strcmp(typeString, NSSIZE_SIGNATURE2) ||
                     !strcmp(typeString, CGSIZE_SIGNATURE)
                     ) {
                NSSize *size = (NSSize *)objc_value;
                NuCell *list = [[[NuCell alloc] init] autorelease];
                id cursor = list;
                [cursor setCar:[NSNumber numberWithDouble:size->width]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:size->height]];
                return list;
            }
#ifdef NU_CCTYPES
            else if (
                     !strcmp(typeString, CCCOLOR3B_SIGNATURE)
                     ) {
                ccColor3B *color = (ccColor3B *)objc_value;
                NuCell *list = [[[NuCell alloc] init] autorelease];
                id cursor = list;
                [cursor setCar:[NSNumber numberWithUnsignedChar:color->r]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithUnsignedChar:color->g]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithUnsignedChar:color->b]];
                return list;
            }
#endif
            else if (
                     !strcmp(typeString, CLLOCATIONCOORDINATE2D_SIGNATURE)
                     ) {
                CLLocationCoordinate2D *loc = (CLLocationCoordinate2D *) objc_value;
                NuCell *list = [[[NuCell alloc] init] autorelease];
                id cursor = list;
                [cursor setCar:[NSNumber numberWithDouble:loc->latitude]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:loc->longitude]];
                return list;
            }
            else if (
                     !strcmp(typeString, MKCOORDINATEREGION_SIGNATURE)
                     ) {
                MKCoordinateRegion *region = (MKCoordinateRegion *) objc_value;
                NuCell *list = [[[NuCell alloc] init] autorelease];
                id cursor = list;
                [cursor setCar:[NSNumber numberWithDouble:region->center.latitude]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:region->center.longitude]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:region->span.latitudeDelta]];
                [cursor setCdr:[[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
                [cursor setCar:[NSNumber numberWithDouble:region->span.longitudeDelta]];
                return list;
            }            
            else if (
                     !strcmp(typeString, FFI_FF_SIGNATURE)
                     ) {
                float *val = (float *) objc_value;
                return nulist(nufloat(val[0]), nufloat(val[1]), nil);
            }                
            else if (
                     !strcmp(typeString, FFI_FFFF_SIGNATURE) ||
                     !strcmp(typeString, FFI_CPBB_SIGNATURE)
                     ) {
                float *val = (float *) objc_value;
                return nulist(nufloat(val[0]), nufloat(val[1]), nufloat(val[2]), nufloat(val[3]), nil);
            }
            else if (!strcmp(typeString, CGAFFINETRANSFORM_SIGNATURE)) {
                float *val = (float *) objc_value;
                return nulist(nufloat(val[0]), nufloat(val[1]), nufloat(val[2]), nufloat(val[3]), nufloat(val[4]), nufloat(val[5]), nil);
            }
            else {
                NSLog(@"UNIMPLEMENTED: can't wrap structure of type %s", typeString);
            }
        }
        case '*':
        {
            return [NSString stringWithCString:*((char **)objc_value) encoding:NSUTF8StringEncoding];
        }
        case 'B':
        {
            if (*((unsigned int *)objc_value) == 0)
                return [NSNull null];
            else
                return [NSNumber numberWithInt:1];
        }
        case '^':
        {
            if (!strcmp(typeString, "^v")) {
                if (*((unsigned long *)objc_value) == 0)
                    return [NSNull null];
                else {
                    id nupointer = [[[NuPointer alloc] init] autorelease];
                    [nupointer setPointer:*((void **)objc_value)];
                    [nupointer setTypeString:[NSString stringWithCString:typeString encoding:NSUTF8StringEncoding]];
                    return nupointer;
                }
            }
            else if (!strcmp(typeString, "^@")) {
                id reference = [[[NuReference alloc] init] autorelease];
                [reference setPointer:*((id**)objc_value)];
                return reference;
            }
            // Certain pointer types are essentially just ids.
            // CGImageRef is one. As we find others, we can add them here.
            else if (!strcmp(typeString, "^{CGImage=}")) {
                id result = *((id *)objc_value);
                return result ? result : (id)[NSNull null];
            }
            else {
                if (*((unsigned long *)objc_value) == 0)
                    return [NSNull null];
                else {
                    id nupointer = [[[NuPointer alloc] init] autorelease];
                    [nupointer setPointer:*((void **)objc_value)];
                    [nupointer setTypeString:[NSString stringWithCString:typeString encoding:NSUTF8StringEncoding]];
                    return nupointer;
                }
            }
            return [NSNull null];
        }
        default:
            NSLog (@"UNIMPLEMENTED: unable to wrap object of type %s", typeString);
            return [NSNull null];
    }
    
}

void raise_argc_exception(SEL s, NSUInteger count, NSUInteger given)
{
    if (given != count) {
        [NSException raise:@"NuIncorrectNumberOfArguments"
                    format:@"Incorrect number of arguments to selector %s. Received %d but expected %d",
         sel_getName(s),
         given,
         count];
    }
}

#define BUFSIZE 500

id nu_calling_objc_method_handler(id target, Method m, NSMutableArray *args)
{
    // this call seems to force the class's +initialize method to be called.
    [target class];
    
    //NSLog(@"calling ObjC method %s with target of class %@", sel_getName(method_getName(m)), [target class]);
    
    IMP imp = method_getImplementation(m);
    
    // if the imp has an associated block, this is a nu-to-nu call.
    // skip going through the ObjC runtime and evaluate the block directly.
    NuBlock *block = nil;
    if (nu_block_table && 
        ((block = [nu_block_table objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long)imp]]))) {
        //NSLog(@"nu calling nu method %s of class %@", sel_getName(method_getName(m)), [target class]);
        id arguments = [[NuCell alloc] init];
        id cursor = arguments;
        NSUInteger argc = [args count];
        int i;
        for (i = 0; i < argc; i++) {
            NuCell *nextCell = [[NuCell alloc] init];
            [cursor setCdr:nextCell];
            [nextCell release];
            cursor = [cursor cdr];
            [cursor setCar:[args objectAtIndex:i]];
        }
        id result = [block evalWithArguments:[arguments cdr] context:nil self:target];
        [arguments release];
        // ensure that methods declared to return void always return void.
        char return_type_buffer[BUFSIZE];
        method_getReturnType(m, return_type_buffer, BUFSIZE);
        return (!strcmp(return_type_buffer, "v")) ? (id)[NSNull null] : result;
    }
    
    id result; 
    // if we get here, we're going through the ObjC runtime to make the call.
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    SEL s = method_getName(m);
    result = [NSNull null];
    
    // dynamically construct the method call
    
    //the method_***** functions seems to count c blocks twice, i.e. they separate
    //the @ and ?. Using an NSMethodSignature seems to be an easy way around it.
    //However, it appears to have some flaws as it causes 'nuke test' to fail
#define USE_SIG 1
    
#if USE_SIG
	NSMethodSignature *sig = [target methodSignatureForSelector:s];
	NSUInteger argument_count = [sig numberOfArguments];
    BOOL zeroArguments = NO;
	if (argument_count == 0)
	{
        // - [NSMethodSignature numberOfArguments] returns 0 if there are no arguments, but we expect 2 (cmd and self).
        // If we get zero, we use method_getNumberOfArguments() here, and method_getArgumentType() below.
        // This works around Apple's bug in the method_*** functions, but allows 'nuke test' to pass
        argument_count =  method_getNumberOfArguments(m);
        zeroArguments = YES;
	}
#else
    int argument_count = method_getNumberOfArguments(m);
#endif
	if ( [args count] != argument_count-2) {
		
		raise_argc_exception(s, argument_count-2, [args count]);
    }
    else {        
        char return_type_buffer[BUFSIZE], arg_type_buffer[BUFSIZE];
        method_getReturnType(m, return_type_buffer, BUFSIZE);
        ffi_type *result_type = ffi_type_for_objc_type(&return_type_buffer[0]);
        void *result_value = value_buffer_for_objc_type(&return_type_buffer[0]);
        ffi_type **argument_types = (ffi_type **) malloc (argument_count * sizeof(ffi_type *));
        void **argument_values = (void **) malloc (argument_count * sizeof(void *));
        int *argument_needs_retained = (int *) malloc (argument_count * sizeof(int));
        int i;
        for (i = 0; i < argument_count; i++) {
#if USE_SIG
			if (zeroArguments) {
			    method_getArgumentType(m, i, &arg_type_buffer[0], BUFSIZE);
			} else {
			    strncpy(&arg_type_buffer[0], [sig getArgumentTypeAtIndex:i], BUFSIZE);
		    }
#else
            method_getArgumentType(m, i, &arg_type_buffer[0], BUFSIZE);
#endif
			
			argument_types[i] = ffi_type_for_objc_type(&arg_type_buffer[0]);
            argument_values[i] = value_buffer_for_objc_type(&arg_type_buffer[0]);
            if (i == 0)
                *((id *) argument_values[i]) = target;
            else if (i == 1)
                *((SEL *) argument_values[i]) = method_getName(m);
            else
                argument_needs_retained[i-2] = set_objc_value_from_nu_value(argument_values[i], [args objectAtIndex:(i-2)], &arg_type_buffer[0]);
        }
        ffi_cif cif2;
        int status = ffi_prep_cif(&cif2, FFI_DEFAULT_ABI, (unsigned int) argument_count, result_type, argument_types);
        if (status != FFI_OK) {
            NSLog (@"failed to prepare cif structure");
        }
        else {
            const char *method_name = sel_getName(method_getName(m));
            BOOL callingInitializer = !strncmp("init", method_name, 4);
            if (callingInitializer) {
                [target retain]; // in case an init method releases its target (to return something else), we preemptively retain it
            }
            // call the method handler
            ffi_call(&cif2, FFI_FN(imp), result_value, argument_values);
            // extract the return value
            result = get_nu_value_from_objc_value(result_value, &return_type_buffer[0]);
            // NSLog(@"result is %@", result);
            // NSLog(@"retain count %d", [result retainCount]);
            
            // Return values should not require a release.
            // Either they are owned by an existing object or are autoreleased.
            // Exceptions to this rule are handled below.
            // Since these methods create new objects that aren't autoreleased, we autorelease them.
            bool already_retained =               // see Anguish/Buck/Yacktman, p. 104
            (s == @selector(alloc)) || (s == @selector(allocWithZone:))
            || (s == @selector(copy)) || (s == @selector(copyWithZone:))
            || (s == @selector(mutableCopy)) || (s == @selector(mutableCopyWithZone:))
            || (s == @selector(new));
            //NSLog(@"already retained? %d", already_retained);
            if (already_retained) {
                [result autorelease];                
            }
            
            if (callingInitializer) {
                if (result == target) {
                    // NSLog(@"undoing preemptive retain of init target %@", [target className]);
                    [target release]; // undo our preemptive retain
                } else {
                    // NSLog(@"keeping preemptive retain of init target %@", [target className]);
                }
            }
            
            for (i = 0; i < [args count]; i++) {
                if (argument_needs_retained[i])
                    [[args objectAtIndex:i] retainReferencedObject];
            }
            
            // free the value structures
            for (i = 0; i < argument_count; i++) {
                free(argument_values[i]);
            }
            free(argument_values);
            free(result_value);
            free(argument_types);
            free(argument_needs_retained);
        }
    }
    [result retain];
    [pool drain];
    [result autorelease];
    return result;
}

@interface NSMethodSignature (UndocumentedInterface)
+ (id) signatureWithObjCTypes:(const char*)types;
@end

void objc_calling_nu_method_handler(ffi_cif* cif, void* returnvalue, void** args, void* userdata)
{
    int argc = cif->nargs - 2;
    id rcv = *((id*)args[0]);                     // this is the object getting the message
    // unused: SEL sel = *((SEL*)args[1]);
    
    // in rare cases, we need an autorelease pool (specifically detachNewThreadSelector:toTarget:withObject:)
    // previously we used a private api to verify that one existed before creating a new one. Now we just make one.
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NuBlock *block = ((NuBlock **)userdata)[1];
    //NSLog(@"----------------------------------------");
    //NSLog(@"calling block %@", [block stringValue]);
    id arguments = [[NuCell alloc] init];
    id cursor = arguments;
    int i;
    for (i = 0; i < argc; i++) {
        NuCell *nextCell = [[NuCell alloc] init];
        [cursor setCdr:nextCell];
        [nextCell release];
        cursor = [cursor cdr];
        id value = get_nu_value_from_objc_value(args[i+2], ((char **)userdata)[i+2]);
        [cursor setCar:value];
    }
    id result = [block evalWithArguments:[arguments cdr] context:nil self:rcv];
    //NSLog(@"in nu method handler, putting result %@ in %x with type %s", [result stringValue], (int) returnvalue, ((char **)userdata)[0]);
    char *resultType = (((char **)userdata)[0])+1;// skip the first character, it's a flag
    set_objc_value_from_nu_value(returnvalue, result, resultType);
#ifdef __ppc__
    // It appears that at least on PowerPC architectures, small values (short, char, ushort, uchar) passed in via
    // the ObjC runtime use their actual type while function return values are coerced up to integers.
    // I suppose this is because values are passed as arguments in memory and returned in registers.
    // This may also be the case on x86 but is unobserved because x86 is little endian.
    switch (resultType[0]) {
        case 'C':
        {
            *((unsigned int *) returnvalue) = *((unsigned char *) returnvalue);
            break;
        }
        case 'c':
        {
            *((int *) returnvalue) = *((char *) returnvalue);
            break;
        }
        case 'S':
        {
            *((unsigned int *) returnvalue) = *((unsigned short *) returnvalue);
            break;
        }
        case 's':
        {
            *((int *) returnvalue) = *((short *) returnvalue);
            break;
        }
    }
#endif
    
    if (((char **)userdata)[0][0] == '!') {
        //NSLog(@"retaining result for object %@, count = %d", *(id *)returnvalue, [*(id *)returnvalue retainCount]);
        [*((id *)returnvalue) retain];
    }
    [arguments release];
    if (pool) {
        if (resultType[0] == '@')
            [*((id *)returnvalue) retain];
        [pool drain];
        if (resultType[0] == '@')
            [*((id *)returnvalue) autorelease];
    }
}

char **generate_userdata(SEL sel, NuBlock *block, const char *signature)
{
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:signature];
    const char *return_type_string = [methodSignature methodReturnType];
    NSUInteger argument_count = [methodSignature numberOfArguments];
    char **userdata = (char **) malloc ((argument_count+3) * sizeof(char*));
    userdata[0] = (char *) malloc (2 + strlen(return_type_string));
    const char *methodName = sel_getName(sel);
    BOOL returnsRetainedResult = NO;
    if ((!strcmp(methodName, "alloc")) ||
        (!strcmp(methodName, "allocWithZone:")) ||
        (!strcmp(methodName, "copy")) ||
        (!strcmp(methodName, "copyWithZone:")) ||
        (!strcmp(methodName, "mutableCopy")) ||
        (!strcmp(methodName, "mutableCopyWithZone:")) ||
        (!strcmp(methodName, "new")))
        returnsRetainedResult = YES;
    if (returnsRetainedResult)
        sprintf(userdata[0], "!%s", return_type_string);
    else
        sprintf(userdata[0], " %s", return_type_string);
    //NSLog(@"constructing handler for method %s with %d arguments and returnType %s", methodName, argument_count, userdata[0]);
    userdata[1] = (char *) block;
    [block retain];
    int i;
    for (i = 0; i < argument_count; i++) {
        const char *argument_type_string = [methodSignature getArgumentTypeAtIndex:i];
        if (i > 1) userdata[i] = strdup(argument_type_string);
    }
    userdata[argument_count] = NULL;
    return userdata;
}

IMP construct_method_handler(SEL sel, NuBlock *block, const char *signature)
{
    char **userdata = generate_userdata(sel, block, signature);
    IMP imp = handler_with_selector(sel, block, signature, userdata);
    if (imp) {
        return imp;
    }
    int argument_count = 0;
    while (userdata[argument_count] != 0) argument_count++;
#if 0
    const char *methodName = sel_getName(sel);
    NSLog(@"using libffi to construct handler for method %s with %d arguments and signature %s", methodName, argument_count, signature);
#endif
    ffi_type **argument_types = (ffi_type **) malloc ((argument_count+1) * sizeof(ffi_type *));
    ffi_type *result_type = ffi_type_for_objc_type(userdata[0]+1);
    argument_types[0] = ffi_type_for_objc_type("@");
    argument_types[1] = ffi_type_for_objc_type(":");
    for (int i = 2; i < argument_count; i++)
        argument_types[i] = ffi_type_for_objc_type(userdata[i]);
    argument_types[argument_count] = NULL;
    ffi_cif *cif = (ffi_cif *)malloc(sizeof(ffi_cif));
    if (cif == NULL) {
        NSLog(@"unable to prepare closure for signature %s (could not allocate memory for cif structure)", signature);
        return NULL;
    }
    int status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argument_count, result_type, argument_types);
    if (status != FFI_OK) {
        NSLog(@"unable to prepare closure for signature %s (ffi_prep_cif failed)", signature);
        return NULL;
    }
    ffi_closure *closure = (ffi_closure *)mmap(NULL, sizeof(ffi_closure), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (closure == (ffi_closure *) -1) {
        NSLog(@"unable to prepare closure for signature %s (mmap failed with error %d)", signature, errno);
        return NULL;
    }
    if (closure == NULL) {
        NSLog(@"unable to prepare closure for signature %s (could not allocate memory for closure)", signature);
        return NULL;
    }
    if (ffi_prep_closure(closure, cif, objc_calling_nu_method_handler, userdata) != FFI_OK) {
        NSLog(@"unable to prepare closure for signature %s (ffi_prep_closure failed)", signature);
        return NULL;
    }
    if (mprotect(closure, sizeof(closure), PROT_READ | PROT_EXEC) == -1) {
        NSLog(@"unable to prepare closure for signature %s (mprotect failed with error %d)", signature, errno);
        return NULL;
    }
    return (IMP) closure;
}

id add_method_to_class(Class c, NSString *methodName, NSString *signature, NuBlock *block)
{
    const char *method_name_str = [methodName cStringUsingEncoding:NSUTF8StringEncoding];
    const char *signature_str = [signature cStringUsingEncoding:NSUTF8StringEncoding];
    SEL selector = sel_registerName(method_name_str);
    
    //NuSymbolTable *symbolTable = [[block context] objectForKey:SYMBOLS_KEY];
    //[[block context] setPossiblyNullObject:[[NuClass alloc] initWithClass:c] forKey:[symbolTable symbolWithString:@"_class"]];
    
    if (!c) {
        return [[[NuImp alloc] initWithBlock:block signature:signature_str] autorelease];
    }
    
    IMP imp = construct_method_handler(selector, block, signature_str);
    if (imp == NULL) {
        NSLog(@"failed to construct handler for %s(%s)", method_name_str, signature_str);
        return [NSNull null];
    }
    
    // save the block in a hash table keyed by the imp.
    // this will let us introspect methods and optimize nu-to-nu method calls
    if (!nu_block_table) nu_block_table = [[NSMutableDictionary alloc] init];
    // watch for problems caused by these ugly casts...
    [nu_block_table setObject:block forKey:[NSNumber numberWithUnsignedLong:(unsigned long) imp]];
    // insert the method handler in the class method table
    nu_class_replaceMethod(c, selector, imp, signature_str);
    //NSLog(@"setting handler for %s(%s) in class %s", method_name_str, signature_str, class_getName(c));
    return [NSNull null];
    
}

@interface NuBridgedFunction ()
{
    char *name;
    char *signature;
    void *function;
}
@end

@implementation NuBridgedFunction

- (NSString *)stringValue
{
    return [NSString stringWithFormat:@"<%@: %s \"%s\">", [self className], name, signature];
}

- (void) dealloc
{
    free(name);
    free(signature);
    [super dealloc];
}

- (NuBridgedFunction *) initWithStaticFunction:(void *)fn name:(char *)n signature:(char *)s
{
    function = fn;
    name = strdup(n);
    signature = strdup(s);
    return self;
}

- (NuBridgedFunction *) initWithName:(NSString *)n signature:(NSString *)s
{
    name = strdup([n cStringUsingEncoding:NSUTF8StringEncoding]);
    signature = strdup([s cStringUsingEncoding:NSUTF8StringEncoding]);
    function = dlsym(RTLD_DEFAULT, name);
    if (!function) {
        [NSException raise:@"NuCantFindBridgedFunction"
                    format:@"%s\n%s\n%s\n", dlerror(),
         "If you are using a release build, try rebuilding with the KEEP_PRIVATE_EXTERNS variable set.",
         "In Xcode, check the 'Preserve Private External Symbols' checkbox."];
    }
    return self;
}

+ (NuBridgedFunction *) functionWithName:(NSString *)name signature:(NSString *)signature
{
    const char *function_name = [name cStringUsingEncoding:NSUTF8StringEncoding];
    void *function = dlsym(RTLD_DEFAULT, function_name);
    if (!function) {
        [NSException raise:@"NuCantFindBridgedFunction"
                    format:@"%s\n%s\n%s\n", dlerror(),
         "If you are using a release build, try rebuilding with the KEEP_PRIVATE_EXTERNS variable set.",
         "In Xcode, check the 'Preserve Private External Symbols' checkbox."];
    }
    NuBridgedFunction *wrapper = [[[NuBridgedFunction alloc] initWithName:name signature:signature] autorelease];
    return wrapper;
}

+ (NuBridgedFunction *) staticFunction:(void *)func name:(char *)name signature:(char *)signature
{
    return [[[NuBridgedFunction alloc] initWithStaticFunction:func name:name signature:signature] autorelease];
}

- (id) evalWithArguments:(id) cdr context:(NSMutableDictionary *) context
{
    //NSLog(@"----------------------------------------");
    //NSLog(@"calling C function %s with signature %s", name, signature);
    id result;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    char *return_type_identifier = strdup(signature);
    nu_markEndOfObjCTypeString(return_type_identifier, strlen(return_type_identifier));
    
    int argument_count = 0;
    char *argument_type_identifiers[100];
    char *cursor = &signature[strlen(return_type_identifier)];
    while (*cursor != 0) {
        argument_type_identifiers[argument_count] = strdup(cursor);
        nu_markEndOfObjCTypeString(argument_type_identifiers[argument_count], strlen(cursor));
        cursor = &cursor[strlen(argument_type_identifiers[argument_count])];
        argument_count++;
    }
    //NSLog(@"calling return type is %s", return_type_identifier);
    int i;
    for (i = 0; i < argument_count; i++) {
        //    NSLog(@"argument %d type is %s", i, argument_type_identifiers[i]);
    }
    
    ffi_cif *cif = (ffi_cif *)malloc(sizeof(ffi_cif));
    
    ffi_type *result_type = ffi_type_for_objc_type(return_type_identifier);
    ffi_type **argument_types = (argument_count == 0) ? NULL : (ffi_type **) malloc (argument_count * sizeof(ffi_type *));
    for (i = 0; i < argument_count; i++)
        argument_types[i] = ffi_type_for_objc_type(argument_type_identifiers[i]);
    
    int status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argument_count, result_type, argument_types);
    if (status != FFI_OK) {
        NSLog (@"failed to prepare cif structure");
        return [NSNull null];
    }
    
    id arg_cursor = cdr;
    void *result_value = value_buffer_for_objc_type(return_type_identifier);
    void **argument_values = (void **) malloc (argument_count * sizeof(void *));
    
    for (i = 0; i < argument_count; i++) {
        argument_values[i] = value_buffer_for_objc_type( argument_type_identifiers[i]);
        id arg_value = [[arg_cursor car] evalWithContext:context];
        set_objc_value_from_nu_value(argument_values[i], arg_value, argument_type_identifiers[i]);
        arg_cursor = [arg_cursor cdr];
    }
    ffi_call(cif, FFI_FN(function), result_value, argument_values);
    result = get_nu_value_from_objc_value(result_value, return_type_identifier);
    
    // free the value structures
    for (i = 0; i < argument_count; i++) {
        free(argument_values[i]);
        free(argument_type_identifiers[i]);
    }
    free(argument_values);
    free(result_value);
    free(return_type_identifier);
    free(argument_types);
    free(cif);
    
    [result retain];
    [pool drain];
    [result autorelease];
    return result;
}

@end

@implementation NuBridgedConstant

+ (id) constantWithName:(NSString *) name signature:(NSString *) signature
{
    const char *constant_name = [name cStringUsingEncoding:NSUTF8StringEncoding];
    void *constant = dlsym(RTLD_DEFAULT, constant_name);
    if (!constant) {
        NSLog(@"%s", dlerror());
        NSLog(@"If you are using a release build, try rebuilding with the KEEP_PRIVATE_EXTERNS variable set.");
        NSLog(@"In Xcode, check the 'Preserve Private External Symbols' checkbox.");
        return nil;
    }
    return get_nu_value_from_objc_value(constant, [signature cStringUsingEncoding:NSUTF8StringEncoding]);
}

@end


NuSymbol *oneway_symbol, *in_symbol, *out_symbol, *inout_symbol, *bycopy_symbol, *byref_symbol, *const_symbol,
*void_symbol, *star_symbol, *id_symbol, *voidstar_symbol, *idstar_symbol, *int_symbol, *long_symbol, *NSComparisonResult_symbol,
*BOOL_symbol, *double_symbol, *float_symbol, *NSRect_symbol, *NSPoint_symbol, *NSSize_symbol, *NSRange_symbol,
*CGRect_symbol, *CGPoint_symbol, *CGSize_symbol,
*SEL_symbol, *Class_symbol;


void prepare_symbols(NuSymbolTable *symbolTable)
{
    oneway_symbol = [symbolTable symbolWithString:@"oneway"];
    in_symbol = [symbolTable symbolWithString:@"in"];
    out_symbol = [symbolTable symbolWithString:@"out"];
    inout_symbol = [symbolTable symbolWithString:@"inout"];
    bycopy_symbol = [symbolTable symbolWithString:@"bycopy"];
    byref_symbol = [symbolTable symbolWithString:@"byref"];
    const_symbol = [symbolTable symbolWithString:@"const"];
    void_symbol = [symbolTable symbolWithString:@"void"];
    star_symbol = [symbolTable symbolWithString:@"*"];
    id_symbol = [symbolTable symbolWithString:@"id"];
    voidstar_symbol = [symbolTable symbolWithString:@"void*"];
    idstar_symbol = [symbolTable symbolWithString:@"id*"];
    int_symbol = [symbolTable symbolWithString:@"int"];
    long_symbol = [symbolTable symbolWithString:@"long"];
    NSComparisonResult_symbol = [symbolTable symbolWithString:@"NSComparisonResult"];
    BOOL_symbol = [symbolTable symbolWithString:@"BOOL"];
    double_symbol = [symbolTable symbolWithString:@"double"];
    float_symbol = [symbolTable symbolWithString:@"float"];
    NSRect_symbol = [symbolTable symbolWithString:@"NSRect"];
    NSPoint_symbol = [symbolTable symbolWithString:@"NSPoint"];
    NSSize_symbol = [symbolTable symbolWithString:@"NSSize"];
    NSRange_symbol = [symbolTable symbolWithString:@"NSRange"];
    CGRect_symbol = [symbolTable symbolWithString:@"CGRect"];
    CGPoint_symbol = [symbolTable symbolWithString:@"CGPoint"];
    CGSize_symbol = [symbolTable symbolWithString:@"CGSize"];    
    SEL_symbol = [symbolTable symbolWithString:@"SEL"];
    Class_symbol = [symbolTable symbolWithString:@"Class"];
}

NSString *signature_for_identifier(NuCell *cell, NuSymbolTable *symbolTable)
{
    static NuSymbolTable *currentSymbolTable = nil;
    if (currentSymbolTable != symbolTable) {
        prepare_symbols(symbolTable);
        currentSymbolTable = symbolTable;
    }
    NSMutableArray *modifiers = nil;
    NSMutableString *signature = [NSMutableString string];
    id cursor = cell;
    BOOL finished = NO;
    while (cursor && cursor != Nu__null) {
        if (finished) {
            // ERROR!
            NSLog(@"I can't bridge this return type yet: %@ (%@)", [cell stringValue], signature);
            return @"?";
        }
        id cursor_car = [cursor car];
        if (cursor_car == oneway_symbol) {
            if (!modifiers) modifiers = [NSMutableArray array];
            [modifiers addObject:@"V"];
        }
        else if (cursor_car == in_symbol) {
            if (!modifiers) modifiers = [NSMutableArray array];
            [modifiers addObject:@"n"];
        }
        else if (cursor_car == out_symbol) {
            if (!modifiers) modifiers = [NSMutableArray array];
            [modifiers addObject:@"o"];
        }
        else if (cursor_car == inout_symbol) {
            if (!modifiers) modifiers = [NSMutableArray array];
            [modifiers addObject:@"N"];
        }
        else if (cursor_car == bycopy_symbol) {
            if (!modifiers) modifiers = [NSMutableArray array];
            [modifiers addObject:@"O"];
        }
        else if (cursor_car == byref_symbol) {
            if (!modifiers) modifiers = [NSMutableArray array];
            [modifiers addObject:@"R"];
        }
        else if (cursor_car == const_symbol) {
            if (!modifiers) modifiers = [NSMutableArray array];
            [modifiers addObject:@"r"];
        }
        else if (cursor_car == void_symbol) {
            if (![cursor cdr] || ([cursor cdr] == [NSNull null])) {
                if (modifiers)
                    [signature appendString:[[modifiers sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@""]];
                [signature appendString:@"v"];
                finished = YES;
            }
            else if ([[cursor cdr] car] == star_symbol) {
                [signature appendString:@"^v"];
                cursor = [cursor cdr];
                finished = YES;
            }
        }
        else if (cursor_car == id_symbol) {
            if (![cursor cdr] || ([cursor cdr] == [NSNull null])) {
                if (modifiers)
                    [signature appendString:[[modifiers sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@""]];
                [signature appendString:@"@"];
                finished = YES;
            }
            else if ([[cursor cdr] car] == star_symbol) {
                [signature appendString:@"^@"];
                cursor = [cursor cdr];
                finished = YES;
            }
        }
        else if (cursor_car == voidstar_symbol) {
            [signature appendString:@"^v"];
            finished = YES;
        }
        else if (cursor_car == idstar_symbol) {
            [signature appendString:@"^@"];
            finished = YES;
        }
        else if (cursor_car == int_symbol) {
            [signature appendString:@"i"];
            finished = YES;
        }
        else if (cursor_car == long_symbol) {
            [signature appendString:@"l"];
            finished = YES;
        }
        else if (cursor_car == NSComparisonResult_symbol) {
            if (sizeof(NSComparisonResult) == 4)
                [signature appendString:@"i"];
            else
                [signature appendString:@"q"];
            finished = YES;
        }
        else if (cursor_car == BOOL_symbol) {
            [signature appendString:@"C"];
            finished = YES;
        }
        else if (cursor_car == double_symbol) {
            [signature appendString:@"d"];
            finished = YES;
        }
        else if (cursor_car == float_symbol) {
            [signature appendString:@"f"];
            finished = YES;
        }
        else if (cursor_car == NSRect_symbol) {
            [signature appendString:@NSRECT_SIGNATURE0];
            finished = YES;
        }
        else if (cursor_car == NSPoint_symbol) {
            [signature appendString:@NSPOINT_SIGNATURE0];
            finished = YES;
        }
        else if (cursor_car == NSSize_symbol) {
            [signature appendString:@NSSIZE_SIGNATURE0];
            finished = YES;
        }
        else if (cursor_car == NSRange_symbol) {
            [signature appendString:@NSRANGE_SIGNATURE];
            finished = YES;
        }        
        else if (cursor_car == CGRect_symbol) {
            [signature appendString:@CGRECT_SIGNATURE0];
            finished = YES;
        }
        else if (cursor_car == CGPoint_symbol) {
            [signature appendString:@CGPOINT_SIGNATURE];
            finished = YES;
        }
        else if (cursor_car == CGSize_symbol) {
            [signature appendString:@CGSIZE_SIGNATURE];
            finished = YES;
        }                
        else if (cursor_car == SEL_symbol) {
            [signature appendString:@":"];
            finished = YES;
        }
        else if (cursor_car == Class_symbol) {
            [signature appendString:@"#"];
            finished = YES;
        }
        cursor = [cursor cdr];
    }
    if (finished)
        return signature;
    else {
        NSLog(@"I can't bridge this return type yet: %@ (%@)", [cell stringValue], signature);
        return @"?";
    }
}

id help_add_method_to_class(Class classToExtend, id cdr, NSMutableDictionary *context, BOOL addClassMethod)
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    
    id returnType = [NSNull null];
    id selector = [[NuCell alloc] init];
    id argumentTypes = [NSNull null];
    id argumentNames = [NSNull null];
    id isSymbol = [symbolTable symbolWithString:@"is"];
    id cursor = cdr;
    id selector_cursor = nil;
    id argumentTypes_cursor = nil;
    id argumentNames_cursor = nil;
    
    if (cursor && (cursor != [NSNull null]) && ([cursor car] != isSymbol)) {
        // scan the return type
        if (![[cursor car] atom]) {
            returnType = [cursor car] ;
            cursor = [cursor cdr];
        }
        else {
            // The return type specifier must be a list (in parens).  If it is missing, leave it as null.
            returnType = Nu__null;
        }
        if (cursor && (cursor != [NSNull null])) {
            [selector setCar:[cursor car]];       // scan a part of the selector
            cursor = [cursor cdr];
            if (cursor && (cursor != [NSNull null])) {
                if ([cursor car] != isSymbol) {
                    argumentTypes = [[[NuCell alloc] init] autorelease];
                    argumentNames = [[[NuCell alloc] init] autorelease];
                    if (![[cursor car] atom]) {
                        // the argument type specifier must be a list. If it is missing, we'll use a default.
                        [argumentTypes setCar:[cursor car]];
                        cursor = [cursor cdr];
                    }
                    if (cursor && (cursor != [NSNull null])) {
                        [argumentNames setCar:[cursor car]];
                        cursor = [cursor cdr];
                        if (cursor && (cursor != [NSNull null])) {
                            selector_cursor = selector;
                            argumentTypes_cursor = argumentTypes;
                            argumentNames_cursor = argumentNames;
                        }
                    }
                }
            }
        }
    }
    // scan each remaining part of the selector
    while (cursor && (cursor != [NSNull null]) && ([cursor car] != isSymbol)) {
        [selector_cursor setCdr:[[[NuCell alloc] init] autorelease]];
        [argumentTypes_cursor setCdr:[[[NuCell alloc] init] autorelease]];
        [argumentNames_cursor setCdr:[[[NuCell alloc] init] autorelease]];
        selector_cursor = [selector_cursor cdr];
        argumentTypes_cursor = [argumentTypes_cursor cdr];
        argumentNames_cursor = [argumentNames_cursor cdr];
        
        [selector_cursor setCar:[cursor car]];
        cursor = [cursor cdr];
        if (cursor && (cursor != [NSNull null])) {
            if (![[cursor car] atom]) {
                // the argument type specifier must be a list.  If it is missing, we'll use a default.
                [argumentTypes_cursor setCar:[cursor car]];
                cursor = [cursor cdr];
            }
            if (cursor && (cursor != [NSNull null])) {
                [argumentNames_cursor setCar:[cursor car]];
                cursor = [cursor cdr];
            }
        }
    }
    
    if (cursor && (cursor != [NSNull null])) {
        //NSLog(@"selector: %@", [selector stringValue]);
        //NSLog(@"argument names: %@", [argumentNames stringValue]);
        //NSLog(@"argument types:%@", [argumentTypes stringValue]);
        //NSLog(@"returns: %@", [returnType stringValue]);
        
        // skip the is
        cursor = [cursor cdr];
        
        // combine the selectors into the method name
        NSMutableString *methodName = [[[NSMutableString alloc] init] autorelease];
        selector_cursor = selector;
        while (selector_cursor && (selector_cursor != [NSNull null])) {
            [methodName appendString:[[selector_cursor car] stringValue]];
            selector_cursor = [selector_cursor cdr];
        }
        
        NSMutableString *signature = nil;
        
        if ((returnType == Nu__null) || ([argumentTypes length] < [argumentNames length])) {
            // look up the signature
            SEL selector = sel_registerName([methodName cStringUsingEncoding:NSUTF8StringEncoding]);
            NSMethodSignature *methodSignature = [classToExtend instanceMethodSignatureForSelector:selector];
            
            if (!methodSignature)
                methodSignature = [classToExtend methodSignatureForSelector:selector];
            if (methodSignature)
                signature = [NSMutableString stringWithString:[methodSignature typeString]];
            // if we can't find a signature, use a default
            if (!signature) {
                // NSLog(@"no signature found.  treating all arguments and the return type as (id)");
                signature = [NSMutableString stringWithString:@"@@:"];
                int i;
                for (i = 0; i < [argumentNames length]; i++) {
                    [signature appendString:@"@"];
                }
            }
        }
        else {
            // build the signature, first get the return type
            signature = [[NSMutableString alloc] init];
            [signature appendString:signature_for_identifier(returnType, symbolTable)];
            
            // then add the common stuff
            [signature appendString:@"@:"];
            
            // then describe the arguments
            argumentTypes_cursor = argumentTypes;
            while (argumentTypes_cursor && (argumentTypes_cursor != [NSNull null])) {
                id typeIdentifier = [argumentTypes_cursor car];
                [signature appendString:signature_for_identifier(typeIdentifier, symbolTable)];
                argumentTypes_cursor = [argumentTypes_cursor cdr];
            }
        }
        id body = cursor;
        NuBlock *block = [[[NuBlock alloc] initWithParameters:argumentNames body:body context:context] autorelease];
        [[block context]
         setPossiblyNullObject:methodName
         forKey:[symbolTable symbolWithString:@"_method"]];
        return add_method_to_class(
                                   addClassMethod ? object_getClass(classToExtend) : classToExtend,
                                   methodName, signature, block);
    }
    else {
        // not good. you probably forgot the "is" in your method declaration.
        [NSException raise:@"NuBadMethodDeclaration"
                    format:@"invalid method declaration: %@",
         [cdr stringValue]];
        return nil;
    }
}

#ifdef __BLOCKS__

id make_cblock (NuBlock *nuBlock, NSString *signature);
void objc_calling_nu_block_handler(ffi_cif* cif, void* returnvalue, void** args, void* userdata);
char **generate_block_userdata(NuBlock *nuBlock, const char *signature);
void *construct_block_handler(NuBlock *block, const char *signature);

@interface NuBridgedBlock ()
{
	NuBlock *nuBlock;	
	id cBlock;
}
@end

@implementation NuBridgedBlock

+(id)cBlockWithNuBlock:(NuBlock*)nb signature:(NSString*)sig
{
	return [[[[self alloc] initWithNuBlock:nb signature:sig] autorelease] cBlock];
}

-(id)initWithNuBlock:(NuBlock*)nb signature:(NSString*)sig
{
	nuBlock = [nb retain];
	cBlock = make_cblock(nb,sig);
	
	return self;
}

-(NuBlock*)nuBlock
{return [[nuBlock retain] autorelease];}

-(id)cBlock
{return [[cBlock retain] autorelease];}

-(void)dealloc
{
	[nuBlock release];
	[cBlock release];
	[super dealloc];
}

@end

//the caller gets ownership of the block
id make_cblock (NuBlock *nuBlock, NSString *signature)
{
	void *funcptr = construct_block_handler(nuBlock, [signature UTF8String]);
    
	int i = 0xFFFF;
	void(^cBlock)(void)=[^(void){printf("%i",i);} copy];
	
#ifdef __x86_64__
	/*  this is what happens when a block is called on x86 64
	 mov    %rax,-0x18(%rbp)		//the pointer to the block object is in rax
	 mov    -0x18(%rbp),%rax
	 mov    0x10(%rax),%rax			//the pointer to the block function is at +0x10 into the block object
	 mov    -0x18(%rbp),%rdi		//the first argument (this examples has no others) is always the pointer to the block object
	 callq  *%rax
     */
	//2*(sizeof(void*)) = 0x10
	*((void **)(id)cBlock + 2) = (void *)funcptr;
#else
	/*  this is what happens when a block is called on x86 32
	 mov    %eax,-0x14(%ebp)		//the pointer to the block object is in eax
	 mov    -0x14(%ebp),%eax		
	 mov    0xc(%eax),%eax			//the pointer to the block function is at +0xc into the block object
	 mov    %eax,%edx
	 mov    -0x14(%ebp),%eax		//the first argument (this examples has no others) is always the pointer to the block object
	 mov    %eax,(%esp)
	 call   *%edx
	 */
	//3*(sizeof(void*)) = 0xc
	*((void **)(id)cBlock + 3) = (void *)funcptr;
#endif
	return cBlock;
}

void objc_calling_nu_block_handler(ffi_cif* cif, void* returnvalue, void** args, void* userdata)
{
    int argc = cif->nargs - 1;
	//void *ptr = (void*)args[0]  //don't need this first parameter
    // see objc_calling_nu_method_handler
	
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NuBlock *block = ((NuBlock **)userdata)[1];
    //NSLog(@"----------------------------------------");
    //NSLog(@"calling block %@", [block stringValue]);
    id arguments = [[NuCell alloc] init];
    id cursor = arguments;
    int i;
    for (i = 0; i < argc; i++) {
        NuCell *nextCell = [[NuCell alloc] init];
        [cursor setCdr:nextCell];
        [nextCell release];
        cursor = [cursor cdr];
        id value = get_nu_value_from_objc_value(args[i+1], ((char **)userdata)[i+2]);
        [cursor setCar:value];
    }
	//NSLog(@"in nu method handler, using arguments %@", [arguments stringValue]);
    id result = [block evalWithArguments:[arguments cdr] context:nil];
    //NSLog(@"in nu method handler, putting result %@ in %x with type %s", [result stringValue], (size_t) returnvalue, ((char **)userdata)[0]);
    char *resultType = (((char **)userdata)[0])+1;// skip the first character, it's a flag
    set_objc_value_from_nu_value(returnvalue, result, resultType);
    [arguments release];
    if (pool) {
        if (resultType[0] == '@')
            [*((id *)returnvalue) retain];
        [pool release];
        if (resultType[0] == '@')
            [*((id *)returnvalue) autorelease];
    }
}

char **generate_block_userdata(NuBlock *nuBlock, const char *signature)
{
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:signature];
    const char *return_type_string = [methodSignature methodReturnType];
    NSUInteger argument_count = [methodSignature numberOfArguments];
    char **userdata = (char **) malloc ((argument_count+3) * sizeof(char*));
    userdata[0] = (char *) malloc (2 + strlen(return_type_string));
    
	//assume blocks never return retained results
	sprintf(userdata[0], " %s", return_type_string);
    
	//so first element is return type, second is nuBlock
    userdata[1] = (char *) nuBlock;
    [nuBlock retain];
    int i;
    for (i = 0; i < argument_count; i++) {
        const char *argument_type_string = [methodSignature getArgumentTypeAtIndex:i];
        userdata[i+2] = strdup(argument_type_string);
    }
    userdata[argument_count+2] = NULL;
	
#if 0
	NSLog(@"Userdata for block: %@, signature: %s", [nuBlock stringValue], signature);
	for (int i = 0; i < argument_count+2; i++)
	{	if (i != 1)
        NSLog(@"userdata[%i] = %s",i,userdata[i]);	}
#endif
    return userdata;
}


void *construct_block_handler(NuBlock *block, const char *signature)
{
    char **userdata = generate_block_userdata(block, signature);
    
    int argument_count = 0;
    while (userdata[argument_count] != 0) argument_count++;
	argument_count-=1; //unlike a method call, c blocks have one, not two hidden args (see comments in make_cblock()
#if 0
	NSLog(@"using libffi to construct handler for nu block with %d arguments and signature %s", argument_count, signature);
#endif
	
	
	
    ffi_type **argument_types = (ffi_type **) malloc ((argument_count+1) * sizeof(ffi_type *));
    ffi_type *result_type = ffi_type_for_objc_type(userdata[0]+1);
    
    argument_types[0] = ffi_type_for_objc_type("^?");
	
    for (int i = 1; i < argument_count; i++)
        argument_types[i] = ffi_type_for_objc_type(userdata[i+1]);
    argument_types[argument_count] = NULL;
    ffi_cif *cif = (ffi_cif *)malloc(sizeof(ffi_cif));
    if (cif == NULL) {
        NSLog(@"unable to prepare closure for signature %s (could not allocate memory for cif structure)", signature);
        return NULL;
    }
    int status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argument_count, result_type, argument_types);
    if (status != FFI_OK) {
        NSLog(@"unable to prepare closure for signature %s (ffi_prep_cif failed)", signature);
        return NULL;
    }
    ffi_closure *closure = (ffi_closure *)mmap(NULL, sizeof(ffi_closure), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (closure == (ffi_closure *) -1) {
        NSLog(@"unable to prepare closure for signature %s (mmap failed with error %d)", signature, errno);
        return NULL;
    }
    if (closure == NULL) {
        NSLog(@"unable to prepare closure for signature %s (could not allocate memory for closure)", signature);
        return NULL;
    }
    if (ffi_prep_closure(closure, cif, objc_calling_nu_block_handler, userdata) != FFI_OK) {
        NSLog(@"unable to prepare closure for signature %s (ffi_prep_closure failed)", signature);
        return NULL;
    }
    if (mprotect(closure, sizeof(closure), PROT_READ | PROT_EXEC) == -1) {
        NSLog(@"unable to prepare closure for signature %s (mprotect failed with error %d)", signature, errno);
        return NULL;
    }
    return (void*)closure;
}

#endif //__BLOCKS__



#pragma mark - NuCell.m


#pragma mark - NuClass.m

// getting a specific method...
// (set x (((Convert classMethods) select: (fn (m) (eq (m name) "passRect:"))) objectAtIndex:0))

@interface NuClass ()
{
    Class c;
    BOOL isRegistered;
}
@end

@implementation NuClass

+ (NuClass *) classWithName:(NSString *)string
{
    const char *name = [string cStringUsingEncoding:NSUTF8StringEncoding];
    Class class = objc_getClass(name);
    if (class) {
        return [[[self alloc] initWithClass:class] autorelease];
    }
    else {
        return nil;
    }
}

+ (NuClass *) classWithClass:(Class) class
{
    if (class) {
        return [[[self alloc] initWithClass:class] autorelease];
    }
    else {
        return nil;
    }
}

- (id) initWithClassNamed:(NSString *) string
{
    const char *name = [string cStringUsingEncoding:NSUTF8StringEncoding];
    Class class = objc_getClass(name);
    return [self initWithClass: class];
}

- (id) initWithClass:(Class) class
{
    if ((self = [super init])) {
        c = class;
        isRegistered = YES;                           // unless we explicitly set otherwise
    }
    return self;
}

+ (NSArray *) all
{
    NSMutableArray *array = [NSMutableArray array];
    int numClasses = objc_getClassList(NULL, 0);
    if(numClasses > 0) {
        Class *classes = (Class *) malloc( sizeof(Class) * numClasses );
        objc_getClassList(classes, numClasses);
        int i = 0;
        while (i < numClasses) {
            NuClass *class = [[[NuClass alloc] initWithClass:classes[i]] autorelease];
            [array addObject:class];
            i++;
        }
        free(classes);
    }
    return array;
}

- (NSString *) name
{
    //	NSLog(@"calling NuClass name for object %@", self);
    return [NSString stringWithCString:class_getName(c) encoding:NSUTF8StringEncoding];
}

- (NSString *) stringValue
{
    return [self name];
}

- (Class) wrappedClass
{
    return c;
}

- (NSArray *) classMethods
{
    NSMutableArray *array = [NSMutableArray array];
    unsigned int method_count;
    Method *method_list = class_copyMethodList(object_getClass([self wrappedClass]), &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        [array addObject:[[[NuMethod alloc] initWithMethod:method_list[i]] autorelease]];
    }
    free(method_list);
    [array sortUsingSelector:@selector(compare:)];
    return array;
}

- (NSArray *) instanceMethods
{
    NSMutableArray *array = [NSMutableArray array];
    unsigned int method_count;
    Method *method_list = class_copyMethodList([self wrappedClass], &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        [array addObject:[[[NuMethod alloc] initWithMethod:method_list[i]] autorelease]];
    }
    free(method_list);
    [array sortUsingSelector:@selector(compare:)];
    return array;
}

/*! Get an array containing the names of the class methods of a class. */
- (NSArray *) classMethodNames
{
    id methods = [self classMethods];
    return [methods mapSelector:@selector(name)];
}

/*! Get an array containing the names of the instance methods of a class. */
- (NSArray *) instanceMethodNames
{
    id methods = [self instanceMethods];
    return [methods mapSelector:@selector(name)];
}

- (BOOL) isDerivedFromClass:(Class) parent
{
    Class myclass = [self wrappedClass];
    if (myclass == parent)
        return true;
    Class superclass = [myclass superclass];
    if (superclass)
        return nu_objectIsKindOfClass(superclass, parent);
    return false;
}

- (NSComparisonResult) compare:(NuClass *) anotherClass
{
    return [[self name] compare:[anotherClass name]];
}

- (NuMethod *) classMethodWithName:(NSString *) methodName
{
    const char *methodNameString = [methodName cStringUsingEncoding:NSUTF8StringEncoding];
    NuMethod *method = Nu__null;
    unsigned int method_count;
    Method *method_list = class_copyMethodList(object_getClass([self wrappedClass]), &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        if (!strcmp(methodNameString, sel_getName(method_getName(method_list[i])))) {
            method = [[[NuMethod alloc] initWithMethod:method_list[i]] autorelease];
        }
    }
    free(method_list);
    return method;
}

- (NuMethod *) instanceMethodWithName:(NSString *) methodName
{
    const char *methodNameString = [methodName cStringUsingEncoding:NSUTF8StringEncoding];
    NuMethod *method = Nu__null;
    unsigned int method_count;
    Method *method_list = class_copyMethodList([self wrappedClass], &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        if (!strcmp(methodNameString, sel_getName(method_getName(method_list[i])))) {
            method = [[[NuMethod alloc] initWithMethod:method_list[i]] autorelease];
        }
    }
    free(method_list);
    return method;
}

- (id) addInstanceMethod:(NSString *)methodName signature:(NSString *)signature body:(NuBlock *)block
{
    //NSLog(@"adding instance method %@", methodName);
    return add_method_to_class(c, methodName, signature, block);
}

- (id) addClassMethod:(NSString *)methodName signature:(NSString *)signature body:(NuBlock *)block
{
    NSLog(@"adding class method %@", methodName);
    return add_method_to_class(object_getClass(c), /* c->isa, */ methodName, signature, block);
}

- (id) addInstanceVariable:(NSString *)variableName signature:(NSString *)signature
{
    //NSLog(@"adding instance variable %@", variableName);
    nu_class_addInstanceVariable_withSignature(c, [variableName cStringUsingEncoding:NSUTF8StringEncoding], [signature cStringUsingEncoding:NSUTF8StringEncoding]);
    return Nu__null;
}

- (BOOL) isEqual:(NuClass *) anotherClass
{
    return c == anotherClass->c;
}

- (void) setSuperclass:(NuClass *) newSuperclass
{
    struct nu_objc_class
    {
        Class isa;
        Class super_class;
        // other stuff...
    };
    ((struct nu_objc_class *) self->c)->super_class = newSuperclass->c;
}

- (BOOL) isRegistered
{
    return isRegistered;
}

- (void) setRegistered:(BOOL) value
{
    isRegistered = value;
}

- (void) registerClass
{
    if (isRegistered == NO) {
        objc_registerClassPair(c);
        isRegistered = YES;
    }
}

- (id) handleUnknownMessage:(id) cdr withContext:(NSMutableDictionary *) context
{
    return [[self wrappedClass] handleUnknownMessage:cdr withContext:context];
}

- (NSArray *) instanceVariableNames {
    NSMutableArray *names = [NSMutableArray array];
    
    unsigned int ivarCount = 0;
    // Ivar *ivarList = class_copyIvarList(c, &ivarCount);
    
    NSLog(@"%d ivars", ivarCount);
    return names;
}

- (BOOL) addPropertyWithName:(NSString *) name {
    const objc_property_attribute_t attributes[10];
    unsigned int attributeCount = 0;
    return class_addProperty(c, [name cStringUsingEncoding:NSUTF8StringEncoding],
                             attributes, 
                             attributeCount);    
}

- (NuProperty *) propertyWithName:(NSString *) name {
    objc_property_t property = class_getProperty(c, [name cStringUsingEncoding:NSUTF8StringEncoding]);
    
    return [NuProperty propertyWithProperty:(objc_property_t) property];
}

- (NSArray *) properties {
    unsigned int property_count;
    objc_property_t *property_list = class_copyPropertyList(c, &property_count);
    
    NSMutableArray *properties = [NSMutableArray array];
    for (int i = 0; i < property_count; i++) {
        [properties addObject:[NuProperty propertyWithProperty:property_list[i]]];
    }    
    free(property_list);
    return properties;
}

//OBJC_EXPORT objc_property_t class_getProperty(Class cls, const char *name)


@end

#pragma mark - NuEnumerable.m


#pragma mark - NuException.m

@implementation NSException (NuStackTrace)

- (NSString*)dump
{
    NSMutableString* dump = [NSMutableString stringWithString:@""];
    
    // Print the system stack trace (10.6 only)
    if ([self respondsToSelector:@selector(callStackSymbols)])
    {
        [dump appendString:@"\nSystem stack trace:\n"];
        
        NSArray* callStackSymbols = [self callStackSymbols];
        NSUInteger count = [callStackSymbols count];
        for (int i = 0; i < count; i++)
        {
            [dump appendString:[callStackSymbols objectAtIndex:i]];
            [dump appendString:@"\n"];
        }
    }
    
    return dump;
}

@end


void Nu_defaultExceptionHandler(NSException* e)
{
    [e dump];
}

BOOL NuException_verboseExceptionReporting = NO;

@interface NuException () 
{
    NSMutableArray* stackTrace;
}
@end

@implementation NuException

+ (void)setDefaultExceptionHandler
{
    NSSetUncaughtExceptionHandler(*Nu_defaultExceptionHandler);
    
#ifdef IMPORT_EXCEPTION_HANDLING_FRAMEWORK
    [[NSExceptionHandler defaultExceptionHandler]
     setExceptionHandlingMask:(NSHandleUncaughtExceptionMask
                               | NSHandleUncaughtSystemExceptionMask
                               | NSHandleUncaughtRuntimeErrorMask
                               | NSHandleTopLevelExceptionMask
                               | NSHandleOtherExceptionMask)];
#endif
}

+ (void)setVerbose:(BOOL)flag
{
    NuException_verboseExceptionReporting = flag;
}


- (void) dealloc
{
    if (stackTrace)
    {
        [stackTrace removeAllObjects];
        [stackTrace release];
    }
    [super dealloc];
}

- (id)initWithName:(NSString *)name reason:(NSString *)reason userInfo:(NSDictionary *)userInfo
{
    self = [super initWithName:name reason:reason userInfo:userInfo];
    stackTrace = [[NSMutableArray alloc] init];
    return self;
}

- (NSArray*)stackTrace
{
    return stackTrace;
}

- (NuException *)addFunction:(NSString *)function lineNumber:(int)line
{
    return [self addFunction:function lineNumber:line filename:@"TopLevel"];
}

- (NuException *)addFunction:(NSString *)function lineNumber:(int)line filename:(NSString *)filename
{
    NuTraceInfo* traceInfo = [[[NuTraceInfo alloc] initWithFunction:function
                                                         lineNumber:line
                                                           filename:filename]
                              autorelease];
    [stackTrace addObject:traceInfo];
    
    return self;
}

- (NSString *)stringValue
{
    return [self reason];
}


- (NSString*)dumpExcludingTopLevelCount:(NSUInteger)topLevelCount
{
    NSMutableString* dump = [NSMutableString stringWithString:@"Nu uncaught exception: "];
    
    [dump appendString:[NSString stringWithFormat:@"%@: %@\n", [self name], [self reason]]];
    
    NSUInteger count = [stackTrace count] - topLevelCount;
    for (int i = 0; i < count; i++)
    {
        NuTraceInfo* trace = [stackTrace objectAtIndex:i];
        
        NSString* traceString = [NSString stringWithFormat:@"  from %@:%d: in %@\n",
                                 [trace filename],
                                 [trace lineNumber],
                                 [trace function]];
        
        [dump appendString:traceString];
    }
    
    if (NuException_verboseExceptionReporting)
    {
        [dump appendString:[super dump]];
    }
    
    return dump;
}

- (NSString*)dump
{
    return [self dumpExcludingTopLevelCount:0];
}

@end

@interface NuTraceInfo () 
{
    NSString*   filename;
    int         lineNumber;
    NSString*   function;
}
@end

@implementation NuTraceInfo

- (id)initWithFunction:(NSString *)aFunction lineNumber:(int)aLine filename:(NSString *)aFilename
{
    self = [super init];
    
    if (self)
    {
        filename = [aFilename retain];
        lineNumber = aLine;
        function = [aFunction retain];
    }
    return self;
}

- (void)dealloc
{
    [filename release];
    [function release];
    
    [super dealloc];
}

- (NSString *)filename
{
    return filename;
}

- (int)lineNumber
{
    return lineNumber;
}

- (NSString *)function
{
    return function;
}

@end

#pragma mark - NuExtensions.m





@implementation NSMethodSignature(Nu)

- (NSString *) typeString
{
    // in 10.5, we can do this:
    // return [self _typeString];
    NSMutableString *result = [NSMutableString stringWithFormat:@"%s", [self methodReturnType]];
    NSInteger i;
    NSUInteger max = [self numberOfArguments];
    for (i = 0; i < max; i++) {
        [result appendFormat:@"%s", [self getArgumentTypeAtIndex:i]];
    }
    return result;
}

@end


#pragma mark - NuHandler.m

id collect_arguments(struct handler_description *description, va_list ap)
{
    int i = 0;
    char *type;
    id arguments = [[NuCell alloc] init];
    id cursor = arguments;
    while((type = description->description[2+i])) {
        [cursor setCdr:[[[NuCell alloc] init] autorelease]];
        cursor = [cursor cdr];
        // NSLog(@"argument type %d: %s", i, type);
        if (!strcmp(type, "@")) {
            [cursor setCar:va_arg(ap, id)];
        }
        else if (!strcmp(type, "i")) {
            int x = va_arg(ap, int);
            [cursor setCar:get_nu_value_from_objc_value(&x, type)];
        }
        else if (!strcmp(type, "C")) {
            // unsigned char is promoted to int in va_arg()
            //unsigned char x = va_arg(ap, unsigned char);
            int x = va_arg(ap, int);
            [cursor setCar:get_nu_value_from_objc_value(&x, type)];
        }
        else if (!strcmp(type, "f")) {
            // calling this w/ float crashes on intel
            double x = (double) va_arg(ap, double);
            //NSLog(@"argument is %f", *((float *) &x));
            ap = ap - sizeof(float);              // messy, messy...
            [cursor setCar:get_nu_value_from_objc_value(&x, type)];
        }
        else if (!strcmp(type, "d")) {
            double x = va_arg(ap, double);
            //NSLog(@"argument is %lf", x);
            [cursor setCar:get_nu_value_from_objc_value(&x, type)];
        }
        else if (!strcmp(type, ":")) {
            SEL x = va_arg(ap, SEL);
            //NSLog(@"collect_arguments: [:] (SEL) = %@", NSStringFromSelector(x));
            [cursor setCar:get_nu_value_from_objc_value(&x, type)];
        }
        else if (!strcmp(type, "^@")) {
            void *x = va_arg(ap, void *);
            //NSLog(@"argument is %lf", x);
            [cursor setCar:get_nu_value_from_objc_value(&x, type)];
        }
        else if (!strcmp(type, "{CGRect={CGPoint=ff}{CGSize=ff}}")
                 || (!strcmp(type, "{CGRect=\"origin\"{CGPoint=\"x\"f\"y\"f}\"size\"{CGSize=\"width\"f\"height\"f}}"))) {
            CGRect x = va_arg(ap, CGRect);
            [cursor setCar:get_nu_value_from_objc_value(&x, type)];
        }
        else {
            NSLog(@"unsupported argument type %s, see objc/handler.m to add support for it", type);
        }
        i++;
    }
    return arguments;
}

// helper function called by method handlers
void nu_handler(void *return_value, struct handler_description *description, id receiver, va_list ap)
{
    id result = nil;
    @autoreleasepool {
        NuBlock *block = (NuBlock *) description->description[1];
        // NSLog(@"handling %@", [block stringValue]);
        id arguments = collect_arguments(description, ap);

        @try {
            result = [block evalWithArguments:[arguments cdr] context:nil self:receiver];
        } @catch (NuException* nuException) {
            prn([NSString stringWithFormat:@"%s", [[nuException dump] cStringUsingEncoding:NSUTF8StringEncoding]]);
        }
        @catch (id exception) {
            prn([NSString stringWithFormat:@"%s: %s",
                 [[exception name] cStringUsingEncoding:NSUTF8StringEncoding],
                 [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding]]);
        }
        
        if (description->description[0][1] == '@') {
            [result retain];
            if (description->description[0][0] == '!') {
                [result retain];
            }
        }
        if (return_value) {
            set_objc_value_from_nu_value(return_value, result, description->description[0]+1);
        }
        [arguments release];
    }
    if (description->description[0][1] == '@') {
        [result autorelease];
    }
}

IMP handler_returning_void(void *userdata) {
    return imp_implementationWithBlock(^(id receiver, ...) {
        struct handler_description description;
        description.handler = NULL;
        description.description = userdata;
        va_list ap; 
        va_start(ap, receiver);  
        nu_handler(0, &description, receiver, ap);     
    });
}

#define MAKE_HANDLER_WITH_TYPE(type) \
IMP handler_returning_ ## type (void* userdata) \
{ \
return imp_implementationWithBlock(^(id receiver, ...) { \
struct handler_description description; \
description.handler = NULL; \
description.description = userdata; \
va_list ap; \
va_start(ap, receiver); \
type result; \
nu_handler(&result, &description, receiver, ap); \
return result; \
}); \
}

MAKE_HANDLER_WITH_TYPE(id)
MAKE_HANDLER_WITH_TYPE(int)
MAKE_HANDLER_WITH_TYPE(bool)
MAKE_HANDLER_WITH_TYPE(float)
MAKE_HANDLER_WITH_TYPE(double)
MAKE_HANDLER_WITH_TYPE(CGRect)
MAKE_HANDLER_WITH_TYPE(CGPoint)
MAKE_HANDLER_WITH_TYPE(CGSize)
MAKE_HANDLER_WITH_TYPE(NSRange)


IMP handler_with_selector(SEL sel, NuBlock *block, const char *signature, char **userdata)
{
    NSString *returnType = [NSString stringWithCString:userdata[0]+1 encoding:NSUTF8StringEncoding];
    if ([returnType isEqualToString:@"v"]) {  
        return handler_returning_void(userdata);
    } 
    else if ([returnType isEqualToString:@"@"]) {
        return handler_returning_id(userdata);
    }
    else if ([returnType isEqualToString:@"i"]) {
        return handler_returning_int(userdata);
    }  
    else if ([returnType isEqualToString:@"C"]) {
        return handler_returning_bool(userdata);
    }
    else if ([returnType isEqualToString:@"f"]) {
        return handler_returning_float(userdata);
    }
    else if ([returnType isEqualToString:@"d"]) {
        return handler_returning_double(userdata);
    }    
    else if ([returnType isEqualToString:@"{CGRect={CGPoint=ff}{CGSize=ff}}"]) {
        return handler_returning_CGRect(userdata);
    }
    else if ([returnType isEqualToString:@"{CGPoint=ff}"]) {
        return handler_returning_CGPoint(userdata);
    }
    else if ([returnType isEqualToString:@"{CGSize=ff}"]) {
        return handler_returning_CGSize(userdata);
    }
    else if ([returnType isEqualToString:@"{_NSRange=II}"]) {
        return handler_returning_NSRange(userdata);
    } 

    // this is only a problem on iOS.
    NSLog(@"UNKNOWN RETURN TYPE %@", returnType);
    return NULL;
}

#pragma mark - NuMacro_0.m
@interface NuMacro_0 ()
{
@protected
    NuCell *body;
	NSMutableSet *gensyms;
}
@end

@implementation NuMacro_0

+ (id) macroWithBody:(NuCell *)b
{
    return [[[self alloc] initWithBody:b] autorelease];
}

- (void) dealloc
{
    [body release];
    [super dealloc];
}

- (NuCell *) body
{
    return body;
}

- (NSSet *) gensyms
{
    return gensyms;
}

- (void) collectGensyms:(NuCell *)cell
{
    id car = [cell car];
    if ([car atom]) {
        if (nu_objectIsKindOfClass(car, [NuSymbol class]) && [car isGensym]) {
            [gensyms addObject:car];
        }
    }
    else if (car && (car != Nu__null)) {
        [self collectGensyms:car];
    }
    id cdr = [cell cdr];
    if (cdr && (cdr != Nu__null)) {
        [self collectGensyms:cdr];
    }
}

- (id) initWithBody:(NuCell *)b
{
    if ((self = [super init])) {
        body = [b retain];
        gensyms = [[NSMutableSet alloc] init];
        [self collectGensyms:body];
    }
    return self;
}

- (NSString *) stringValue
{
    return [NSString stringWithFormat:@"(mac0 %@)", [body stringValue]];
}

- (id) body:(NuCell *) oldBody withGensymPrefix:(NSString *) prefix symbolTable:(NuSymbolTable *) symbolTable
{
    NuCell *newBody = [[[NuCell alloc] init] autorelease];
    id car = [oldBody car];
    if (car == Nu__null) {
        [newBody setCar:car];
    }
    else if ([car atom]) {
        if (nu_objectIsKindOfClass(car, [NuSymbol class]) && [car isGensym]) {
            [newBody setCar:[symbolTable symbolWithString:[NSString stringWithFormat:@"%@%@", prefix, [car stringValue]]]];
        }
        else if (nu_objectIsKindOfClass(car, [NSString class])) {
            // Here we replace gensyms in interpolated strings.
            // The current solution is workable but fragile;
            // we just blindly replace the gensym names with their expanded names.
            // It would be better to
            // 		1. only replace gensym names in interpolated expressions.
            // 		2. ensure substitutions never overlap.  To do this, I think we should
            //           a. order gensyms by size and do the longest ones first.
            //           b. make the gensym transformation idempotent.
            // That's for another day.
            // For now, I just substitute each gensym name with its expansion.
            //
            NSMutableString *tempString = [NSMutableString stringWithString:car];
            //NSLog(@"checking %@", tempString);
            NSEnumerator *gensymEnumerator = [gensyms objectEnumerator];
            NuSymbol *gensymSymbol;
            while ((gensymSymbol = [gensymEnumerator nextObject])) {
                //NSLog(@"gensym is %@", [gensymSymbol stringValue]);
                [tempString replaceOccurrencesOfString:[gensymSymbol stringValue]
                                            withString:[NSString stringWithFormat:@"%@%@", prefix, [gensymSymbol stringValue]]
                                               options:0 range:NSMakeRange(0, [tempString length])];
            }
            //NSLog(@"setting string to %@", tempString);
            [newBody setCar:tempString];
        }
        else {
            [newBody setCar:car];
        }
    }
    else {
        [newBody setCar:[self body:car withGensymPrefix:prefix symbolTable:symbolTable]];
    }
    id cdr = [oldBody cdr];
    if (cdr && (cdr != Nu__null)) {
        [newBody setCdr:[self body:cdr withGensymPrefix:prefix symbolTable:symbolTable]];
    }
    else {
        [newBody setCdr:cdr];
    }
    return newBody;
}

- (id) expandUnquotes:(id) oldBody withContext:(NSMutableDictionary *) context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    if (oldBody == [NSNull null])
        return oldBody;
    id unquote = [symbolTable symbolWithString:@"unquote"];
    id car = [oldBody car];
    id cdr = [oldBody cdr];
    if ([car atom]) {
        if (car == unquote) {
            return [[cdr car] evalWithContext:context];
        }
        else {
            NuCell *newBody = [[[NuCell alloc] init] autorelease];
            [newBody setCar:car];
            [newBody setCdr:[self expandUnquotes:cdr withContext:context]];
            return newBody;
        }
    }
    else {
        NuCell *newBody = [[[NuCell alloc] init] autorelease];
        [newBody setCar:[self expandUnquotes:car withContext:context]];
        [newBody setCdr:[self expandUnquotes:cdr withContext:context]];
        return newBody;
    }
}


- (id) expandAndEval:(id)cdr context:(NSMutableDictionary *)calling_context evalFlag:(BOOL)evalFlag
{
    NuSymbolTable *symbolTable = [calling_context objectForKey:SYMBOLS_KEY];
    
    // save the current value of margs
    id old_margs = [calling_context objectForKey:[symbolTable symbolWithString:@"margs"]];
    // set the arguments to the special variable "margs"
    [calling_context setPossiblyNullObject:cdr forKey:[symbolTable symbolWithString:@"margs"]];
    // evaluate the body of the block in the calling context (implicit progn)
    
    // if the macro contains gensyms, give them a unique prefix
    NSUInteger gensymCount = [[self gensyms] count];
    id gensymPrefix = nil;
    if (gensymCount > 0) {
        gensymPrefix = [NSString stringWithFormat:@"g%ld", random()];
    }
    
    id bodyToEvaluate = (gensymCount == 0)
    ? (id)body : [self body:body withGensymPrefix:gensymPrefix symbolTable:symbolTable];
    
    // uncomment this to get the old (no gensym) behavior.
    //bodyToEvaluate = body;
    //NSLog(@"evaluating %@", [bodyToEvaluate stringValue]);
    
    id value = [self expandUnquotes:bodyToEvaluate withContext:calling_context];
    
	if (evalFlag)
	{
		id cursor = value;
        
	    while (cursor && (cursor != Nu__null)) {
	        value = [[cursor car] evalWithContext:calling_context];
	        cursor = [cursor cdr];
	    }
	}
    
    // restore the old value of margs
    if (old_margs == nil) {
        [calling_context removeObjectForKey:[symbolTable symbolWithString:@"margs"]];
    }
    else {
        [calling_context setPossiblyNullObject:old_margs forKey:[symbolTable symbolWithString:@"margs"]];
    }
    
#if 0
    // I would like to remove gensym values and symbols at the end of a macro's execution,
    // but there is a problem with this: the gensym assignments could be used in a closure,
    // and deleting them would cause that to break. See the testIvarAccessorMacro unit
    // test for an example of this. So for now, the code below is disabled.
    //
    // remove the gensyms from the context; this also releases their assigned values
    NSArray *gensymArray = [gensyms allObjects];
    for (int i = 0; i < gensymCount; i++) {
        NuSymbol *gensymBase = [gensymArray objectAtIndex:i];
        NuSymbol *gensymSymbol = [symbolTable symbolWithString:[NSString stringWithFormat:@"%@%@", gensymPrefix, [gensymBase stringValue]]];
        [calling_context removeObjectForKey:gensymSymbol];
        [symbolTable removeSymbol:gensymSymbol];
    }
#endif
    return value;
}


- (id) expand1:(id)cdr context:(NSMutableDictionary*)calling_context
{
	return [self expandAndEval:cdr context:calling_context evalFlag:NO];
}


- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)calling_context
{
	return [self expandAndEval:cdr context:calling_context evalFlag:YES];
}

@end

#pragma mark - NuMacro_1.m

//#define MACRO1_DEBUG	1

// Following  debug output on and off for this file only
#ifdef MACRO1_DEBUG
#define Macro1Debug(arg...) NSLog(arg)
#else
#define Macro1Debug(arg...)
#endif

@interface NuMacro_1 ()
{
	NuCell *parameters;
}
@end

@implementation NuMacro_1

+ (id) macroWithParameters:(NuCell*)p body:(NuCell *)b
{
    return [[[self alloc] initWithParameters:p body:b] autorelease];
}

- (void) dealloc
{
    [parameters release];
    [super dealloc];
}

- (BOOL) findAtom:(id)atom inSequence:(id)sequence
{
    if (atom == nil || atom == Nu__null)
        return NO;
    
    if (sequence == nil || sequence == Nu__null)
        return NO;
    
    if ([[atom stringValue] isEqualToString:[sequence stringValue]])
        return YES;
    
    if ([sequence class] == [NuCell class]) {
        return (   [self findAtom:atom inSequence:[sequence car]]
                || [self findAtom:atom inSequence:[sequence cdr]]);
    }
    
    return NO;
}

- (id) initWithParameters:(NuCell *)p body:(NuCell *)b
{
    if ((self = [super initWithBody:b])) {
        parameters = [p retain];
        
        if (([parameters length] == 1)
            && ([[[parameters car] stringValue] isEqualToString:@"*args"])) {
            // Skip the check
        }
        else {
            BOOL foundArgs = [self findAtom:@"*args" inSequence:parameters];
            
            if (foundArgs) {
                printf("Warning: Overriding implicit variable '*args'.\n");
            }
        }
    }
    return self;
}

- (NSString *) stringValue
{
    return [NSString stringWithFormat:@"(mac %@ %@)", [parameters stringValue], [body stringValue]];
}

- (void) dumpContext:(NSMutableDictionary*)context
{
#ifdef MACRO1_DEBUG
    NSArray* keys = [context allKeys];
    NSUInteger count = [keys count];
    for (int i = 0; i < count; i++) {
        id key = [keys objectAtIndex:i];
        Macro1Debug(@"contextdump: %@  =  %@  [%@]", key,
                    [[context objectForKey:key] stringValue],
                    [[context objectForKey:key] class]);
    }
#endif
}

- (void) restoreArgs:(id)old_args context:(NSMutableDictionary*)calling_context
{
    NuSymbolTable *symbolTable = [calling_context objectForKey:SYMBOLS_KEY];
    
    if (old_args == nil) {
        [calling_context removeObjectForKey:[symbolTable symbolWithString:@"*args"]];
    }
    else {
        [calling_context setPossiblyNullObject:old_args forKey:[symbolTable symbolWithString:@"*args"]];
    }
}

- (void)restoreBindings:(id)bindings
     forMaskedVariables:(NSMutableDictionary*)maskedVariables
            fromContext:(NSMutableDictionary*)calling_context
{
    id plist = bindings;
    
    while (plist && (plist != Nu__null)) {
        id param = [[plist car] car];
        
        Macro1Debug(@"restoring bindings: looking up key: %@",
                    [param stringValue]);
        
        [calling_context removeObjectForKey:param];
        id pvalue = [maskedVariables objectForKey:param];
        
        Macro1Debug(@"restoring calling context for: %@, value: %@",
                    [param stringValue], [pvalue stringValue]);
        
        if (pvalue) {
            [calling_context setPossiblyNullObject:pvalue forKey:param];
        }
        
        plist = [plist cdr];
    }
}

- (id) destructuringListAppend:(id)lhs withList:(id)rhs
{
    Macro1Debug(@"Append: lhs = %@  rhs = %@", [lhs stringValue], [rhs stringValue]);
    
    if (lhs == nil || lhs == Nu__null)
        return rhs;
    
    if (rhs == nil || rhs == Nu__null)
        return lhs;
    
    id cursor = lhs;
    
    while (   cursor
           && (cursor != Nu__null)
           && [cursor cdr]
           && ([cursor cdr] != Nu__null)) {
        cursor = [cursor cdr];
    }
    
    [cursor setCdr:rhs];
    
    Macro1Debug(@"Append: result = %@", [lhs stringValue]);
    
    return lhs;
}

- (id) mdestructure:(id)pattern withSequence:(id)sequence
{
    Macro1Debug(@"mdestructure: pat: %@  seq: %@", [pattern stringValue], [sequence stringValue]);
    
	// ((and (not pat) seq)
	if (   ((pattern == nil) || (pattern == Nu__null))
	    && !((sequence == Nu__null) || (sequence == nil))) {
        [NSException raise:@"NuDestructureException"
                    format:@"Attempt to match empty pattern to non-empty object %@", [self stringValue]];
    }
    // ((not pat) nil)
    else if ((pattern == nil) || (pattern == Nu__null)) {
        return nil;
    }
    // ((eq pat '_) '())  ; wildcard match produces no binding
    else if ([[pattern stringValue] isEqualToString:@"_"]) {
        return nil;
    }
    // ((symbol? pat)
    //   (let (seq (if (eq ((pat stringValue) characterAtIndex:0) '*')
    //                 (then (list seq))
    //                 (else seq)))
    //        (list (list pat seq))))
    else if ([pattern class] == [NuSymbol class]) {
        id result;
        
        if ([[pattern stringValue] characterAtIndex:0] == '*') {
            // List-ify sequence
            id l = [[[NuCell alloc] init] autorelease];
            [l setCar:sequence];
            result = l;
        }
        else {
            result = sequence;
        }
        
        // (list pattern sequence)
        id p = [[[NuCell alloc] init] autorelease];
        id s = [[[NuCell alloc] init] autorelease];
        
        [p setCar:pattern];
        [p setCdr:s];
        [s setCar:result];
        
        // (list (list pattern sequence))
        id l = [[[NuCell alloc] init] autorelease];
        [l setCar:p];
        
        return l;
    }
    // ((pair? pat)
    //   (if (and (symbol? (car pat))
    //       (eq (((car pat) stringValue) characterAtIndex:0) '*'))
    //       (then (list (list (car pat) seq)))
    //       (else ((let ((bindings1 (mdestructure (car pat) (car seq)))
    //                    (bindings2 (mdestructure (cdr pat) (cdr seq))))
    //                (append bindings1 bindings2))))))
    else if ([pattern class] == [NuCell class]) {
        if (   ([[pattern car] class] == [NuSymbol class])
            && ([[[pattern car] stringValue] characterAtIndex:0] == '*')) {
            
            id l1 = [[[NuCell alloc] init] autorelease];
            id l2 = [[[NuCell alloc] init] autorelease];
            id l3 = [[[NuCell alloc] init] autorelease];
            [l1 setCar:[pattern car]];
            [l1 setCdr:l2];
            [l2 setCar:sequence];
            [l3 setCar:l1];
            
            return l3;
        }
        else {
            if (sequence == nil || sequence == Nu__null) {
                [NSException raise:@"NuDestructureException"
                            format:@"Attempt to match non-empty pattern to empty object"];
            }
            
            id b1 = [self mdestructure:[pattern car] withSequence:[sequence car]];
            id b2 = [self mdestructure:[pattern cdr] withSequence:[sequence cdr]];
            
            id newList = [self destructuringListAppend:b1 withList:b2];
            
            Macro1Debug(@"jsb:   dbind: %@", [newList stringValue]);
            return newList;
        }
    }
    // (else (throw* "NuMatchException"
    //               "pattern is not nil, a symbol or a pair: #{pat}"))))
    else {
        [NSException raise:@"NuDestructureException"
                    format:@"Pattern is not nil, a symbol or a pair: %@", [pattern stringValue]];
    }
    
    // Just for aesthetics...
    return nil;
}

- (id) expandAndEval:(id)cdr context:(NSMutableDictionary*)calling_context evalFlag:(BOOL)evalFlag
{
    NuSymbolTable *symbolTable = [calling_context objectForKey:SYMBOLS_KEY];
    
    NSMutableDictionary* maskedVariables = [[NSMutableDictionary alloc] init];
    
    id plist;
    
    Macro1Debug(@"Dumping context:");
    Macro1Debug(@"---------------:");
#ifdef MACRO1_DEBUG
    [self dumpContext:calling_context];
#endif
    id old_args = [calling_context objectForKey:[symbolTable symbolWithString:@"*args"]];
    [calling_context setPossiblyNullObject:cdr forKey:[symbolTable symbolWithString:@"*args"]];
    
    id destructure;
    
    @try
    {
        // Destructure the arguments
        destructure = [self mdestructure:parameters withSequence:cdr];
    }
    @catch (id exception) {
        // Destructure failed...restore/remove *args
        [self restoreArgs:old_args context:calling_context];
        
        @throw;
    }
    
    plist = destructure;
    while (plist && (plist != Nu__null)) {
        id parameter = [[plist car] car];
        id value = [[[plist car] cdr] car];
        Macro1Debug(@"Destructure: %@ = %@", [parameter stringValue], [value stringValue]);
        
        id pvalue = [calling_context objectForKey:parameter];
        
        if (pvalue) {
            Macro1Debug(@"  Saving context: %@ = %@",
                        [parameter stringValue],
                        [pvalue stringValue]);
            [maskedVariables setPossiblyNullObject:pvalue forKey:parameter];
        }
        
        [calling_context setPossiblyNullObject:value forKey:parameter];
        
        plist = [plist cdr];
    }
    
    Macro1Debug(@"Dumping context (after destructure):");
    Macro1Debug(@"-----------------------------------:");
#ifdef MACRO1_DEBUG
    [self dumpContext:calling_context];
#endif
    // evaluate the body of the block in the calling context (implicit progn)
    id value = Nu__null;
    
    // if the macro contains gensyms, give them a unique prefix
    NSUInteger gensymCount = [[self gensyms] count];
    id gensymPrefix = nil;
    if (gensymCount > 0) {
        gensymPrefix = [NSString stringWithFormat:@"g%ld", random()];
    }
    
    id bodyToEvaluate = (gensymCount == 0)
    ? (id)body : [self body:body withGensymPrefix:gensymPrefix symbolTable:symbolTable];
    
    // Macro1Debug(@"macro evaluating: %@", [bodyToEvaluate stringValue]);
    // Macro1Debug(@"macro context: %@", [calling_context stringValue]);
    
    @try
    {
        // Macro expansion
        id cursor = [self expandUnquotes:bodyToEvaluate withContext:calling_context];
        while (cursor && (cursor != Nu__null)) {
            Macro1Debug(@"macro eval cursor: %@", [cursor stringValue]);
            value = [[cursor car] evalWithContext:calling_context];
            Macro1Debug(@"macro expand value: %@", [value stringValue]);
            cursor = [cursor cdr];
        }
        
        // Now that macro expansion is done, restore the masked calling context variables
        [self restoreBindings:destructure
           forMaskedVariables:maskedVariables
                  fromContext:calling_context];
        
        [maskedVariables release];
        maskedVariables = nil;
        
        // Macro evaluation
        // If we're just macro-expanding, don't do this step...
        if (evalFlag) {
            Macro1Debug(@"About to execute: %@", [value stringValue]);
            value = [value evalWithContext:calling_context];
            Macro1Debug(@"macro eval value: %@", [value stringValue]);
        }
        
        Macro1Debug(@"Dumping context at end:");
        Macro1Debug(@"----------------------:");
#ifdef MACRO1_DEBUG
        [self dumpContext:calling_context];
#endif
        // restore the old value of *args
        [self restoreArgs:old_args context:calling_context];
        
        Macro1Debug(@"macro result: %@", value);
    }
    @catch (id exception) {
        if (maskedVariables) {
            Macro1Debug(@"Caught exception in macro, restoring bindings");
            
            [self restoreBindings:destructure
               forMaskedVariables:maskedVariables
                      fromContext:calling_context];
            
            Macro1Debug(@"Caught exception in macro, releasing maskedVariables");
            
            [maskedVariables release];
        }
        
        Macro1Debug(@"Caught exception in macro, restoring masked arguments");
        
        [self restoreArgs:old_args context:calling_context];
        
        Macro1Debug(@"Caught exception in macro, rethrowing...");
        
        @throw;
    }
    
    return value;
}

- (id) expand1:(id)cdr context:(NSMutableDictionary*)calling_context
{
    return [self expandAndEval:cdr context:calling_context evalFlag:NO];
}

- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)calling_context
{
    return [self expandAndEval:cdr context:calling_context evalFlag:YES];
}

@end

#pragma mark - NuMethod.m
@interface NuMethod ()
{
    Method m;
}
@end

@implementation NuMethod

- (id) initWithMethod:(Method) method
{
    if ((self = [super init])) {
        m = method;
    }
    return self;
}

- (NSString *) name
{
    return m ? [NSString stringWithCString:(sel_getName(method_getName(m))) encoding:NSUTF8StringEncoding] : [NSNull null];
}

- (int) argumentCount
{
    return method_getNumberOfArguments(m);
}

- (NSString *) typeEncoding
{
    return [NSString stringWithCString:method_getTypeEncoding(m) encoding:NSUTF8StringEncoding];
}

- (NSString *) signature
{
    const char *encoding = method_getTypeEncoding(m);
    NSInteger len = strlen(encoding)+1;
    char *signature = (char *) malloc (len * sizeof(char));
    method_getReturnType(m, signature, len);
    NSInteger step = strlen(signature);
    char *start = &signature[step];
    len -= step;
    int argc = method_getNumberOfArguments(m);
    int i;
    for (i = 0; i < argc; i++) {
        method_getArgumentType(m, i, start, len);
        step = strlen(start);
        start = &start[step];
        len -= step;
    }
    //  printf("%s %d %d %s\n", sel_getName(method_getName(m)), i, len, signature);
    id result = [NSString stringWithCString:signature encoding:NSUTF8StringEncoding];
    free(signature);
    return result;
}

- (NSString *) argumentType:(int) i
{
    if (i >= method_getNumberOfArguments(m))
        return nil;
    char *argumentType = method_copyArgumentType(m, i);
    id result = [NSString stringWithCString:argumentType encoding:NSUTF8StringEncoding];
    free(argumentType);
    return result;
}

- (NSString *) returnType
{
    char *returnType = method_copyReturnType(m);
    id result = [NSString stringWithCString:returnType encoding:NSUTF8StringEncoding];
    free(returnType);
    return result;
}

- (NuBlock *) block
{
    IMP imp = method_getImplementation(m);
    NuBlock *block = nil;
    if (nu_block_table) {
        block = [nu_block_table objectForKey:[NSNumber numberWithUnsignedLong:(unsigned long) imp]];
    }
    return block;
}

- (NSComparisonResult) compare:(NuMethod *) anotherMethod
{
    return [[self name] compare:[anotherMethod name]];
}

@end

#pragma mark - NuObjCRuntime.m

IMP nu_class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)
{
    if (class_addMethod(cls, name, imp, types)) {
        return imp;
    } else {
        return class_replaceMethod(cls, name, imp, types);
    }
}

void nu_class_addInstanceVariable_withSignature(Class thisClass, const char *variableName, const char *signature)
{
    extern size_t size_of_objc_type(const char *typeString);
    size_t size = size_of_objc_type(signature);
    uint8_t alignment = log2(size);
    BOOL result = class_addIvar(thisClass, variableName, size, alignment, signature);
    if (!result) {
        [NSException raise:@"NuAddIvarFailed"
                    format:@"failed to add instance variable %s to class %s", variableName, class_getName(thisClass)];
    }
    //NSLog(@"adding ivar named %s to %s, result is %d", variableName, class_getName(thisClass), result);
}

BOOL nu_copyInstanceMethod(Class destinationClass, Class sourceClass, SEL selector)
{
    Method m = class_getInstanceMethod(sourceClass, selector);
    if (!m) {
        return NO;
    }
    IMP imp = method_getImplementation(m);
    if (!imp) {
        return NO;
    }
    const char *signature = method_getTypeEncoding(m);
    if (!signature) {
        return NO;
    }
    BOOL result = (nu_class_replaceMethod(destinationClass, selector, imp, signature) != 0);
    return result;
}

BOOL nu_copyInstanceMethodToSelf(Class sourceClass, SEL sourceSelector, SEL destinationSelector)
{
    Method m = class_getInstanceMethod(sourceClass, sourceSelector);
    if (!m) {
        return NO;
    }
    IMP imp = method_getImplementation(m);
    if (!imp) {
        return NO;
    }
    const char *signature = method_getTypeEncoding(m);
    if (!signature) {
        return NO;
    }
    BOOL result = (nu_class_replaceMethod(sourceClass, destinationSelector, imp, signature) != 0);
    return result;
}

BOOL nu_objectIsKindOfClass(id object, Class class)
{
    if (object == NULL) {
        return NO;
    }
    Class classCursor = object_getClass(object);
    while (classCursor) {
        if (classCursor == class) {
            return YES;
        }
        classCursor = class_getSuperclass(classCursor);
    }
    return NO;    
}

// This function attempts to recognize the return type from a method signature.
// It scans across the signature until it finds a complete return type string,
// then it inserts a null to mark the end of the string.
void nu_markEndOfObjCTypeString(char *type, size_t len)
{
    size_t i;
    char final_char = 0;
    char start_char = 0;
    int depth = 0;
    for (i = 0; i < len; i++) {
        switch(type[i]) {
            case '[':
            case '{':
            case '(':
                // we want to scan forward to a closing character
                if (!final_char) {
                    start_char = type[i];
                    final_char = (start_char == '[') ? ']' : (start_char == '(') ? ')' : '}';
                    depth = 1;
                }
                else if (type[i] == start_char) {
                    depth++;
                }
                break;
            case ']':
            case '}':
            case ')':
                if (type[i] == final_char) {
                    depth--;
                    if (depth == 0) {
                        if (i+1 < len)
                            type[i+1] = 0;
                        return;
                    }
                }
                break;
            case 'b':                             // bitfields
                if (depth == 0) {
                    // scan forward, reading all subsequent digits
                    i++;
                    while ((i < len) && (type[i] >= '0') && (type[i] <= '9'))
                        i++;
                    if (i+1 < len)
                        type[i+1] = 0;
                    return;
                }
            case '^':                             // pointer
            case 'r':                             // const
            case 'n':                             // in
            case 'N':                             // inout
            case 'o':                             // out
            case 'O':                             // bycopy
            case 'R':                             // byref
            case 'V':                             // oneway
                break;                            // keep going, these are all modifiers.
            case 'c': case 'i': case 's': case 'l': case 'q':
            case 'C': case 'I': case 'S': case 'L': case 'Q':
            case 'f': case 'd': case 'B': case 'v': case '*':
            case '@': case '#': case ':': case '?': default:
                if (depth == 0) {
                    if (i+1 < len)
                        type[i+1] = 0;
                    return;
                }
                break;
        }
    }
}
#pragma mark - NuObject.m

@protocol NuCanSetAction
- (void) setAction:(SEL) action;
@end

// use this to look up selectors with symbols
@interface NuSelectorCache : NSObject
{
    NuSymbol *symbol;
    NuSelectorCache *parent;
    NSMutableDictionary *children;
    SEL selector;
}

@end

@implementation NuSelectorCache

+ (NuSelectorCache *) sharedSelectorCache
{
    static NuSelectorCache *sharedCache = nil;
    if (!sharedCache)
        sharedCache = [[self alloc] init];
    return sharedCache;
}

- (NuSelectorCache *) init
{
    if ((self = [super init])) {
        symbol = nil;
        parent = nil;
        children = [[NSMutableDictionary alloc] init];
        selector = NULL;
    }
    return self;
}

- (NuSymbol *) symbol {return symbol;}
- (NuSelectorCache *) parent {return parent;}
- (NSMutableDictionary *) children {return children;}

- (SEL) selector
{
    return selector;
}

- (void) setSelector:(SEL) s
{
    selector = s;
}

- (NuSelectorCache *) initWithSymbol:(NuSymbol *)s parent:(NuSelectorCache *)p
{
    if ((self = [super init])) {
        symbol = s;
        parent = p;
        children = [[NSMutableDictionary alloc] init];
        selector = NULL;
    }
    return self;
}

- (NSString *) selectorName
{
    NSMutableArray *selectorStrings = [NSMutableArray array];
    [selectorStrings addObject:[[self symbol] stringValue]];
    id p = parent;
    while ([p symbol]) {
        [selectorStrings addObject:[[p symbol] stringValue]];
        p = [p parent];
    }
    NSUInteger max = [selectorStrings count];
    NSInteger i;
    for (i = 0; i < max/2; i++) {
        [selectorStrings exchangeObjectAtIndex:i withObjectAtIndex:(max - i - 1)];
    }
    return [selectorStrings componentsJoinedByString:@""];
}

- (NuSelectorCache *) lookupSymbol:(NuSymbol *)childSymbol
{
    NuSelectorCache *child = [children objectForKey:childSymbol];
    if (!child) {
        child = [[[NuSelectorCache alloc] initWithSymbol:childSymbol parent:self] autorelease];
        NSString *selectorString = [child selectorName];
        [child setSelector:sel_registerName([selectorString cStringUsingEncoding:NSUTF8StringEncoding])];
        [children setValue:child forKey:(id)childSymbol];
    }
    return child;
}

@end

@implementation NSObject(Nu)

- (NSString *)className
{
    return nucstr(object_getClassName(self));
}

- (bool) atom
{
    return true;
}

- (id) evalWithContext:(NSMutableDictionary *) context
{
    return self;
}

- (NSString *) stringValue
{
    return [self description];
}

- (id) car
{
    [NSException raise:@"NuCarCalledOnAtom"
                format:@"car called on atom for object %@",
     self];
    return Nu__null;
}

- (id) cdr
{
    [NSException raise:@"NuCdrCalledOnAtom"
                format:@"cdr called on atom for object %@",
     self];
    return Nu__null;
}


- (id) sendMessage:(id)cdr withContext:(NSMutableDictionary *)context
{
    // By themselves, Objective-C objects evaluate to themselves.
    if (!cdr || (cdr == Nu__null))
        return self;
    
    // But when they're at the head of a list, that list is converted into a message that is sent to the object.
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Collect the method selector and arguments.
    // This seems like a bottleneck, and it also lacks flexibility.
    // Replacing explicit string building with the selector cache reduced runtimes by around 20%.
    // Methods with variadic arguments (NSArray arrayWithObjects:...) are not supported.
    NSMutableArray *args = [[NSMutableArray alloc] init];
    id cursor = cdr;
    SEL sel = 0;
    id nextSymbol = [cursor car];
    if (nu_objectIsKindOfClass(nextSymbol, [NuSymbol class])) {
        // The commented out code below was the original approach.
        // methods were identified by concatenating symbols and looking up the resulting method -- on every method call
        // that was slow but simple
        // NSMutableString *selectorString = [NSMutableString stringWithString:[nextSymbol stringValue]];
        NuSelectorCache *selectorCache = [[NuSelectorCache sharedSelectorCache] lookupSymbol:nextSymbol];
        cursor = [cursor cdr];
        while (cursor && (cursor != Nu__null)) {
            [args addObject:[cursor car]];
            cursor = [cursor cdr];
            if (cursor && (cursor != Nu__null)) {
                id nextSymbol = [cursor car];
                if (nu_objectIsKindOfClass(nextSymbol, [NuSymbol class]) && [nextSymbol isLabel]) {
                    // [selectorString appendString:[nextSymbol stringValue]];
                    selectorCache = [selectorCache lookupSymbol:nextSymbol];
                }
                cursor = [cursor cdr];
            }
        }
        // sel = sel_getUid([selectorString cStringUsingEncoding:NSUTF8StringEncoding]);
        sel = [selectorCache selector];
    }
    
    id target = self;
    
    // Look up the appropriate method to call for the specified selector.
    Method m;
    // instead of isMemberOfClass:, which may be blocked by an NSProtocolChecker
    BOOL isAClass = (object_getClass(self) == [NuClass class]);
    if (isAClass) {
        // Class wrappers (objects of type NuClass) get special treatment. Instance methods are sent directly to the class wrapper object.
        // But when a class method is sent to a class wrapper, the method is instead sent as a class method to the wrapped class.
        // This makes it possible to call class methods from Nu, but there is no way to directly call class methods of NuClass from Nu.
        id wrappedClass = [((NuClass *) self) wrappedClass];
        m = class_getClassMethod(wrappedClass, sel);
        if (m)
            target = wrappedClass;
        else
            m = class_getInstanceMethod(object_getClass(self), sel);
    }
    else {
        m = class_getInstanceMethod(object_getClass(self), sel);
        if (!m) m = class_getClassMethod(object_getClass(self), sel);
    }
    id result = Nu__null;
    if (m) {
        // We have a method that matches the selector.
        // First, evaluate the arguments.
        NSMutableArray *argValues = [[NSMutableArray alloc] init];
        NSUInteger i;
        NSUInteger imax = [args count];
        for (i = 0; i < imax; i++) {
            [argValues addObject:[[args objectAtIndex:i] evalWithContext:context]];
        }
        // Then call the method.
        result = nu_calling_objc_method_handler(target, m, argValues);
        [argValues release];
    }
    else {
        // If the head of the list is a label, we treat the list as a property list.
        // We just evaluate the elements of the list and return the result.
        if (nu_objectIsKindOfClass(self, [NuSymbol class]) && [((NuSymbol *)self) isLabel]) {
            NuCell *cell = [[[NuCell alloc] init] autorelease];
            [cell setCar: self];
            id cursor = cdr;
            id result_cursor = cell;
            while (cursor && (cursor != Nu__null)) {
                id arg = [[cursor car] evalWithContext:context];
                [result_cursor setCdr:[[[NuCell alloc] init] autorelease]];
                result_cursor = [result_cursor cdr];
                [result_cursor setCar:arg];
                cursor = [cursor cdr];
            }
            result = cell;
        }
        // Messaging null is ok.
        else if (self == Nu__null) {
        }
        // Test if target specifies another object that should receive the message
        else if ( (target = [target forwardingTargetForSelector:sel]) ) {
            //NSLog(@"found forwarding target: %@ for selector: %@", target, NSStringFromSelector(sel));
            result = [target sendMessage:cdr withContext:context];
        }
        // Otherwise, call the overridable handler for unknown messages.
        else {
            //NSLog(@"calling handle unknown message for %@", [cdr stringValue]);
            result = [self handleUnknownMessage:cdr withContext:context];
            //NSLog(@"result is %@", result);
        }
    }
    
    [args release];
    [result retain];
    [pool drain];
    [result autorelease];
    return result;
}

- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [self sendMessage:cdr withContext:context];
}

+ (id) handleUnknownMessage:(id) cdr withContext:(NSMutableDictionary *) context
{
    [NSException raise:@"NuUnknownMessage"
                format:@"unable to find message handler for %@",
     [cdr stringValue]];
    return Nu__null;
}


- (id) handleUnknownMessage:(id) message withContext:(NSMutableDictionary *) context
{
    // Collect the method selector and arguments.
    // This seems like a bottleneck, and it also lacks flexibility.
    // Replacing explicit string building with the selector cache reduced runtimes by around 20%.
    // Methods with variadic arguments (NSArray arrayWithObjects:...) are not supported.
    NSMutableArray *args = [NSMutableArray array];
    id cursor = message;
    SEL sel = 0;
    id nextSymbol = [cursor car];
    if (nu_objectIsKindOfClass(nextSymbol, [NuSymbol class])) {
        // The commented out code below was the original approach.
        // methods were identified by concatenating symbols and looking up the resulting method -- on every method call
        // that was slow but simple
        // NSMutableString *selectorString = [NSMutableString stringWithString:[nextSymbol stringValue]];
        NuSelectorCache *selectorCache = [[NuSelectorCache sharedSelectorCache] lookupSymbol:nextSymbol];
        cursor = [cursor cdr];
        while (cursor && (cursor != Nu__null)) {
            [args addObject:[cursor car]];
            cursor = [cursor cdr];
            if (cursor && (cursor != Nu__null)) {
                id nextSymbol = [cursor car];
                if (nu_objectIsKindOfClass(nextSymbol, [NuSymbol class]) && [nextSymbol isLabel]) {
                    // [selectorString appendString:[nextSymbol stringValue]];
                    selectorCache = [selectorCache lookupSymbol:nextSymbol];
                }
                cursor = [cursor cdr];
            }
        }
        // sel = sel_getUid([selectorString cStringUsingEncoding:NSUTF8StringEncoding]);
        sel = [selectorCache selector];
    }
    
    // If the object responds to methodSignatureForSelector:, we should create and forward an invocation to it.
    NSMethodSignature *methodSignature = sel ? [self methodSignatureForSelector:sel] : 0;
    if (methodSignature) {
        id result = [NSNull null];
        // Create an invocation to forward.
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:self];
        [invocation setSelector:sel];
        // Set any arguments to the invocation.
        NSUInteger i;
        NSUInteger imax = [args count];
        for (i = 0; i < imax; i++) {
            const char *argument_type = [methodSignature getArgumentTypeAtIndex:i+2];
            char *buffer = value_buffer_for_objc_type(argument_type);
            set_objc_value_from_nu_value(buffer, [[args objectAtIndex:i] evalWithContext:context], argument_type);
            [invocation setArgument:buffer atIndex:i+2];
            free(buffer);
        }
        // Forward the invocation.
        [self forwardInvocation:invocation];
        // Get the return value from the invocation.
        NSUInteger length = [[invocation methodSignature] methodReturnLength];
        if (length > 0) {
            char *buffer = (void *)malloc(length);
            [invocation getReturnValue:buffer];
            result = get_nu_value_from_objc_value(buffer, [methodSignature methodReturnType]);
            free(buffer);
        }
        return result;
    }
    
#define AUTOMATIC_IVAR_ACCESSORS
#ifdef AUTOMATIC_IVAR_ACCESSORS
    //NSLog(@"attempting to access ivar %@", [message stringValue]);
    NSInteger message_length = [message length];
    if (message_length == 1) {
        // try to automatically get an ivar
        NSString *ivarName = [[message car] stringValue];
        if ([self hasValueForIvar:ivarName]) {
            id result = [self valueForIvar:ivarName];
            return result;
        }
    }
    else if (message_length == 2) {
        // try to automatically set an ivar
        if ([[[[message car] stringValue] substringWithRange:NSMakeRange(0,3)] isEqualToString:@"set"]) {
            @try
            {
                id firstArgument = [[message car] stringValue];
                id variableName0 = [[firstArgument substringWithRange:NSMakeRange(3,1)] lowercaseString];
                id variableName1 = [firstArgument substringWithRange:NSMakeRange(4, [firstArgument length] - 5)];
                [self setValue:[[[message cdr] car] evalWithContext:context]
                       forIvar:[NSString stringWithFormat:@"%@%@", variableName0, variableName1]];
                return Nu__null;
            }
            @catch (id error) {
                // NSLog(@"skipping this error: %@", [error description]);
                // no ivar, keep going
            }
        }
    }
#endif
    
    id result = [[message car] evalWithContext:context];
    if (nu_objectIsKindOfClass(result, [NSDictionary class])) {
        NSLog(@"setValuesForKeysWithDictionary: %@", result);
        [self setValuesForKeysWithDictionary:result];
        return self;
    }
    if (nu_valueIsNull(result)) {
        NSLog(@"ignoring message nil");
        return self;
    }
    
    
    NuCell *cell = [[[NuCell alloc] init] autorelease];
    [cell setCar:self];
    [cell setCdr:message];
    [NSException raise:@"NuUnknownMessage"
                format:@"unable to find message handler for %@",
     [cell stringValue]];
    return Nu__null;
}

- (id) valueForIvar:(NSString *) name
{
    Ivar v = class_getInstanceVariable([self class], [name cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!v) {
        // look for sparse ivar storage
        NSMutableDictionary *sparseIvars = [self associatedObjectForKey:@"__nuivars"];
        if (sparseIvars) {
            // NSLog(@"sparse %@", [sparseIvars description]);
            id result = [sparseIvars objectForKey:name];
            if (result) {
                return result;
            } else {
                return Nu__null;
            }
        }        
        return Nu__null;
    }
    void *location = (void *)&(((char *)self)[ivar_getOffset(v)]);
    id result = get_nu_value_from_objc_value(location, ivar_getTypeEncoding(v));
    return result;
}

- (BOOL) hasValueForIvar:(NSString *) name
{
    Ivar v = class_getInstanceVariable([self class], [name cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!v) {
        // look for sparse ivar storage
        NSMutableDictionary *sparseIvars = [self associatedObjectForKey:@"__nuivars"];
        if (sparseIvars) {
            // NSLog(@"sparse %@", [sparseIvars description]);
            id result = [sparseIvars objectForKey:name];
            if (result) {
                return YES;
            } else {
                return NO;
            }
        }        
        return NO;
    }
    //void *location = (void *)&(((char *)self)[ivar_getOffset(v)]);
    //id result = get_nu_value_from_objc_value(location, ivar_getTypeEncoding(v));
    return YES;
}


- (void) setValue:(id) value forIvar:(NSString *)name
{
    Ivar v = class_getInstanceVariable([self class], [name cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!v) {
        NSMutableDictionary *sparseIvars = [self associatedObjectForKey:@"__nuivars"];
        if (!sparseIvars) {
            sparseIvars = [[[NSMutableDictionary alloc] init] autorelease];
            [self setRetainedAssociatedObject:sparseIvars forKey:@"__nuivars"];
        }
        [self willChangeValueForKey:name];
        [sparseIvars setPossiblyNullObject:value forKey:name];
        [self didChangeValueForKey:name];
        return;
    }
    [self willChangeValueForKey:name];
    void *location = (void *)&(((char *)self)[ivar_getOffset(v)]);
    const char *encoding = ivar_getTypeEncoding(v);
    if (encoding && (strlen(encoding) > 0) && (encoding[0] == '@')) {
        [value retain];
        [*((id *)location) release];
    }
    set_objc_value_from_nu_value(location, value, ivar_getTypeEncoding(v));
    [self didChangeValueForKey:name];
}

+ (NSArray *) classMethods
{
    NSMutableArray *array = [NSMutableArray array];
    unsigned int method_count;
    Method *method_list = class_copyMethodList(object_getClass([self class]), &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        [array addObject:[[[NuMethod alloc] initWithMethod:method_list[i]] autorelease]];
    }
    free(method_list);
    [array sortUsingSelector:@selector(compare:)];
    return array;
}

+ (NSArray *) instanceMethods
{
    NSMutableArray *array = [NSMutableArray array];
    unsigned int method_count;
    Method *method_list = class_copyMethodList([self class], &method_count);
    int i;
    for (i = 0; i < method_count; i++) {
        [array addObject:[[[NuMethod alloc] initWithMethod:method_list[i]] autorelease]];
    }
    free(method_list);
    [array sortUsingSelector:@selector(compare:)];
    return array;
}

+ (NSArray *) classMethodNames
{
    Class c = [self class];
    id methods = [c classMethods];
    return [methods mapSelector:@selector(name)];
    //    return [[c classMethods] mapSelector:@selector(name)];
}

+ (NSArray *) instanceMethodNames
{
    Class c = [self class];
    id methods = [c instanceMethods];
    return [methods mapSelector:@selector(name)];
    //    return [[c instanceMethods] mapSelector:@selector(name)];
}

+ (NSArray *) instanceVariableNames
{
    NSMutableArray *array = [NSMutableArray array];
    unsigned int ivar_count;
    Ivar *ivar_list = class_copyIvarList([self class], &ivar_count);
    int i;
    for (i = 0; i < ivar_count; i++) {
        [array addObject:[NSString stringWithCString:ivar_getName(ivar_list[i]) encoding:NSUTF8StringEncoding]];
    }
    free(ivar_list);
    [array sortUsingSelector:@selector(compare:)];
    return array;
}

+ (NSString *) signatureForIvar:(NSString *)name
{
    Ivar v = class_getInstanceVariable([self class], [name cStringUsingEncoding:NSUTF8StringEncoding]);
    return [NSString stringWithCString:ivar_getTypeEncoding(v) encoding:NSUTF8StringEncoding];
}

+ (id) inheritedByClass:(NuClass *) newClass
{
    return nil;
}

+ (id) createSubclassNamed:(NSString *) subclassName
{
    Class c = [self class];
    const char *name = [subclassName cStringUsingEncoding:NSUTF8StringEncoding];
    
    // does the class already exist?
    Class s = objc_getClass(name);
    if (s) {
        // the subclass's superclass must be the current class!
        if (c != [s superclass]) {
            NSLog(@"Warning: Class %s already exists and is not a subclass of %s", name, class_getName(c));
        }
    }
    else {
        s = objc_allocateClassPair(c, name, 0);
        objc_registerClassPair(s);
    }
    NuClass *newClass = [[[NuClass alloc] initWithClass:s] autorelease];
    
    if ([self respondsToSelector:@selector(inheritedByClass:)]) {
        [self inheritedByClass:newClass];
    }
    
    return newClass;
}

/*
 + (id) addInstanceMethod:(NSString *)methodName signature:(NSString *)signature body:(NuBlock *)block
 {
 Class c = [self class];
 return add_method_to_class(c, methodName, signature, block);
 }
 
 + (id) addClassMethod:(NSString *)methodName signature:(NSString *)signature body:(NuBlock *)block
 {
 Class c = [self class]->isa;
 return add_method_to_class(c, methodName, signature, block);
 }
 */
+ (BOOL) copyInstanceMethod:(NSString *) methodName fromClass:(NuClass *)prototypeClass
{
    Class thisClass = [self class];
    Class otherClass = [prototypeClass wrappedClass];
    const char *method_name_str = [methodName cStringUsingEncoding:NSUTF8StringEncoding];
    SEL selector = sel_registerName(method_name_str);
    BOOL result = nu_copyInstanceMethod(thisClass, otherClass, selector);
    return result;
}

+ (BOOL) include:(NuClass *)prototypeClass
{
    NSArray *methods = [prototypeClass instanceMethods];
    NSEnumerator *enumerator = [methods objectEnumerator];
    id method;
    while ((method = [enumerator nextObject])) {
        // NSLog(@"copying method %@", [method name]);
        [self copyInstanceMethod:[method name] fromClass:prototypeClass];
    }
    return true;
}

+ (NSString *) help
{
    return [NSString stringWithFormat:@"This is a class named %s.", class_getName([self class])];
}

- (NSString *) help
{
    return [NSString stringWithFormat:@"This is an instance of %s.", class_getName([self class])];
}

// adapted from the CocoaDev MethodSwizzling page

+ (BOOL) exchangeInstanceMethod:(SEL)sel1 withMethod:(SEL)sel2
{
    Class myClass = [self class];
    Method method1 = NULL, method2 = NULL;
    
    // First, look for the methods
    method1 = class_getInstanceMethod(myClass, sel1);
    method2 = class_getInstanceMethod(myClass, sel2);
    // If both are found, swizzle them
    if ((method1 != NULL) && (method2 != NULL)) {
        method_exchangeImplementations(method1, method2);
        return true;
    }
    else {
        if (method1 == NULL) NSLog(@"swap failed: can't find %s", sel_getName(sel1));
        if (method2 == NULL) NSLog(@"swap failed: can't find %s", sel_getName(sel2));
        return false;
    }
    
    return YES;
}

+ (BOOL) exchangeClassMethod:(SEL)sel1 withMethod:(SEL)sel2
{
    Class myClass = [self class];
    Method method1 = NULL, method2 = NULL;
    
    // First, look for the methods
    method1 = class_getClassMethod(myClass, sel1);
    method2 = class_getClassMethod(myClass, sel2);
    
    // If both are found, swizzle them
    if ((method1 != NULL) && (method2 != NULL)) {
        method_exchangeImplementations(method1, method2);
        return true;
    }
    else {
        if (method1 == NULL) NSLog(@"swap failed: can't find %s", sel_getName(sel1));
        if (method2 == NULL) NSLog(@"swap failed: can't find %s", sel_getName(sel2));
        return false;
    }
    
    return YES;
}

// Concisely set key-value pairs from a property list.

- (id) set:(NuCell *) propertyList
{
    id cursor = propertyList;
    while (cursor && (cursor != Nu__null) && ([cursor cdr]) && ([cursor cdr] != Nu__null)) {
        id key = [cursor car];
        id value = [[cursor cdr] car];
        id label = ([key isKindOfClass:[NuSymbol class]] && [key isLabel]) ? [key labelName] : key;
        if ([label isEqualToString:@"action"] && [self respondsToSelector:@selector(setAction:)]) {
            SEL selector = sel_registerName([value cStringUsingEncoding:NSUTF8StringEncoding]);
            [(id<NuCanSetAction>) self setAction:selector];
        }
        else {
            [self setValue:value forKey:label];
        }
        cursor = [[cursor cdr] cdr];
    }
    return self;
}

- (void) setRetainedAssociatedObject:(id) object forKey:(id) key {
    if ([key isKindOfClass:[NSString class]]) 
        key = [[NuSymbolTable sharedSymbolTable] symbolWithString:key];
    objc_setAssociatedObject(self, key, object, OBJC_ASSOCIATION_RETAIN);
}

- (void) setAssignedAssociatedObject:(id) object forKey:(id) key {
    if ([key isKindOfClass:[NSString class]]) 
        key = [[NuSymbolTable sharedSymbolTable] symbolWithString:key];
    objc_setAssociatedObject(self, key, object, OBJC_ASSOCIATION_ASSIGN);
}

- (void) setCopiedAssociatedObject:(id) object forKey:(id) key {
    if ([key isKindOfClass:[NSString class]]) 
        key = [[NuSymbolTable sharedSymbolTable] symbolWithString:key];
    objc_setAssociatedObject(self, key, object, OBJC_ASSOCIATION_COPY);
}

- (id) associatedObjectForKey:(id) key {
    if ([key isKindOfClass:[NSString class]]) 
        key = [[NuSymbolTable sharedSymbolTable] symbolWithString:key];
    return objc_getAssociatedObject(self, key);
}

- (void) removeAssociatedObjects {
    objc_removeAssociatedObjects(self);
}

// Helper. Included because it's so useful.
- (NSData *) XMLPropertyListRepresentation {
    return [NSPropertyListSerialization dataWithPropertyList:self
                                                      format: NSPropertyListXMLFormat_v1_0
                                                     options:0
                                                       error:nil];
}

// Helper. Included because it's so useful.
- (NSData *) binaryPropertyListRepresentation {
    return [NSPropertyListSerialization dataWithPropertyList:self
                                                      format: NSPropertyListBinaryFormat_v1_0
                                                     options:0
                                                       error:nil];      
}

- (id) pointer
{
    return [NSValue valueWithPointer:self];
}



@end

#pragma mark - NuOperator.m

@implementation NuBreakException
- (id) init
{
    return [super initWithName:@"NuBreakException" reason:@"A break operator was evaluated" userInfo:nil];
}

@end

@implementation NuContinueException
- (id) init
{
    return [super initWithName:@"NuContinueException" reason:@"A continue operator was evaluated" userInfo:nil];
}

@end

@implementation NuReturnException
- (id) initWithValue:(id) v
{
    if ((self = [super initWithName:@"NuReturnException" reason:@"A return operator was evaluated" userInfo:nil])) {
        value = [v retain];
        blockForReturn = nil;
    }
    return self;
}

- (id) initWithValue:(id) v blockForReturn:(id) b
{
    if ((self = [super initWithName:@"NuReturnException" reason:@"A return operator was evaluated" userInfo:nil])) {
        value = [v retain];
        blockForReturn = b;                           // weak reference
    }
    return self;
}

- (void) dealloc
{
    [value release];
    [super dealloc];
}

- (id) value
{
    return value;
}

- (id) blockForReturn
{
    return blockForReturn;
}

@end

@implementation NuOperator : NSObject
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context {return nil;}
- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)context {return [self callWithArguments:cdr context:context];}
@end


#pragma mark - NuParser.m

#define PARSE_NORMAL     0
#define PARSE_COMMENT    1
#define PARSE_STRING     2
#define PARSE_HERESTRING 3
#define PARSE_REGEX      4

// Turn debug output on and off for this file only
//#define PARSER_DEBUG 1

#ifdef PARSER_DEBUG
#define ParserDebug(arg...) NSLog(arg)
#else
#define ParserDebug(arg...)
#endif

@interface NuParser(Internal)
- (int) depth;
- (int) parens;
- (int) state;
- (NuCell *) root;
- (NSMutableArray *) opens;
- (NSString *) stringValue;
- (const char *) cStringUsingEncoding:(NSStringEncoding) encoding;
- (id) init;
- (void) openList;
- (void) closeList;
- (void) addAtom:(id)atom;
- (void) quoteNextElement;
- (void) quasiquoteNextElement;
- (void) quasiquoteEvalNextElement;
- (void) quasiquoteSpliceNextElement;
@end

id atomWithString(NSString *string, NuSymbolTable *symbolTable)
{
    const char *cstring = [string cStringUsingEncoding:NSUTF8StringEncoding];
    char *endptr;
    // If the string can be converted to a long, it's an NSNumber.
    long lvalue = strtol(cstring, &endptr, 0);
    if (*endptr == 0) {
        return [NSNumber numberWithLong:lvalue];
    }
    // If the string can be converted to a double, it's an NSNumber.
    double dvalue = strtod(cstring, &endptr);
    if (*endptr == 0) {
        return [NSNumber numberWithDouble:dvalue];
    }
    // Otherwise, it's a symbol.
    NuSymbol *symbol = [symbolTable symbolWithString:string];
    return symbol;
}

id regexWithString(NSString *string)
{
    // If the first character of the string is a forward slash, it's a regular expression literal.
    if (([string characterAtIndex:0] == '/') && ([string length] > 1)) {
        NSUInteger lastSlash = [string length];
        NSInteger i = lastSlash-1;
        while (i > 0) {
            if ([string characterAtIndex:i] == '/') {
                lastSlash = i;
                break;
            }
            i--;
        }
        // characters after the last slash specify options.
        int options = 0;
        NSInteger j;
        for (j = lastSlash+1; j < [string length]; j++) {
            unichar c = [string characterAtIndex:j];
            switch (c) {
                case 'i': options |= PCRE_CASELESS; break;
                case 's': options |= PCRE_DOTALL; break;
                case 'x': options |= PCRE_EXTENDED; break;
                case 'm': options |= PCRE_MULTILINE; break; // multiline
                default:
                    [NSException raise:@"NuParseError" format:@"unsupported regular expression option character: %C", c];
            }
        }
        NSString *pattern = [string substringWithRange:NSMakeRange(1, lastSlash-1)];
        return [PCRE regexWithPattern:pattern options:options];
    }
    else {
        return nil;
    }
}

#define NU_MAX_PARSER_MACRO_DEPTH 1000

@interface NuParser ()
{
    int state;
    int start;
    int depth;
    int parens;
    int column;
    
	NSMutableArray* readerMacroStack;
	int readerMacroDepth[NU_MAX_PARSER_MACRO_DEPTH];
    
    NSString *filename;
    int linenum;
    int parseEscapes;
    
    NuCell *root;
    NuCell *current;
    bool addToCar;
    NSMutableString *hereString;
    bool hereStringOpened;
    NSMutableArray *stack;
    NSMutableArray *opens;
    NuSymbolTable *symbolTable;
    NSMutableDictionary *context;
    NSMutableString *partial;
    NSMutableString *comments;
    NSString *pattern;                            // used for herestrings
}
@end

@implementation NuParser

+ (NSString *) filename
{
    return [[Nu sharedParser] filename];
}

- (void) setFilename:(NSString *) name
{
    [filename release];
    filename = [name retain];
    linenum = 1;
}

- (NSString *) filename
{
    return filename;
}

- (BOOL) incomplete
{
    return (depth > 0) || (state == PARSE_REGEX) || (state == PARSE_HERESTRING);
}

- (int) depth
{
    return depth;
}

- (int) parens
{
    return parens;
}

- (int) state
{
    return state;
}

- (NuCell *) root
{
    return [root cdr];
}

- (NSMutableArray *) opens
{
    return opens;
}

- (NSMutableDictionary *) context
{
    return context;
}

- (NuSymbolTable *) symbolTable
{
    return symbolTable;
}

- (NSString *) stringValue
{
    return [self description];
}

- (const char *) cStringUsingEncoding:(NSStringEncoding) encoding
{
    return [[self stringValue] cStringUsingEncoding:encoding];
}

- (void) reset
{
    state = PARSE_NORMAL;
    [partial setString:@""];
    depth = 0;
    parens = 0;
    
    [readerMacroStack removeAllObjects];
    
    int i;
    for (i = 0; i < NU_MAX_PARSER_MACRO_DEPTH; i++) {
        readerMacroDepth[i] = 0;
    }
    
    [root release];
    root = current = [[NuCell alloc] init];
    [root setFile:@"top-level" line:1];
    [root setCar:[symbolTable symbolWithString:@"progn"]];
    addToCar = false;
    [stack release];
    stack = [[NSMutableArray alloc] init];
}

- (id) init
{
    if (Nu__null == 0) Nu__null = [NSNull null];
    if ((self = [super init])) {
        
        filename = @"top-level";
        linenum = 1;
        column = 0;
        opens = [[NSMutableArray alloc] init];
        // attach to symbol table (or create one if we want a separate table per parser)
        symbolTable = [[NuSymbolTable sharedSymbolTable] retain];
        // create top-level context
        context = [[NSMutableDictionary alloc] init];
        
        readerMacroStack = [[NSMutableArray alloc] init];
        
        [context setPossiblyNullObject:self forKey:[symbolTable symbolWithString:@"_parser"]];
        [context setPossiblyNullObject:symbolTable forKey:SYMBOLS_KEY];
        
        partial = [[NSMutableString alloc] initWithString:@""];
        
        [self reset];
    }
    return self;
}

- (void) close
{
    // break this retain cycle so the parser can be deleted.
    [context setPossiblyNullObject:[NSNull null] forKey:[symbolTable symbolWithString:@"_parser"]];
}

- (void) dealloc
{
    [opens release];
    [context release];
    [symbolTable release];
    [root release];
    [stack release];
    [comments release];
    [readerMacroStack release];
    [pattern release];
    [partial release];
    [super dealloc];
}

- (void) addAtomCell:(id)atom
{
    ParserDebug(@"addAtomCell: depth = %d  atom = %@", depth, [atom stringValue]);
    
    NuCell *newCell;
    if (comments) {
        NuCellWithComments *newCellWithComments = [[[NuCellWithComments alloc] init] autorelease];
        [newCellWithComments setComments:comments];
        newCell = newCellWithComments;
        [comments release];
        comments = nil;
    }
    else {
        newCell = [[[NuCell alloc] init] autorelease];
        [newCell setFile:filename line:linenum];
    }
    if (addToCar) {
        [current setCar:newCell];
        [stack push:current];
    }
    else {
        [current setCdr:newCell];
    }
    current = newCell;
    [current setCar:atom];
    addToCar = false;
}

- (void) openListCell
{
    ParserDebug(@"openListCell: depth = %d", depth);
    
    depth++;
    NuCell *newCell = [[[NuCell alloc] init] autorelease];
    [newCell setFile:filename line:linenum];
    if (addToCar) {
        [current setCar:newCell];
        [stack push:current];
    }
    else {
        [current setCdr:newCell];
    }
    current = newCell;
    
    addToCar = true;
}

- (void) openList
{
    ParserDebug(@"openList: depth = %d", depth);
    
    while ([readerMacroStack count] > 0) {
        ParserDebug(@"  openList: readerMacro");
        
        [self openListCell];
        ++readerMacroDepth[depth];
        ParserDebug(@"  openList: ++RMD[%d] = %d", depth, readerMacroDepth[depth]);
        [self addAtomCell:
         [symbolTable symbolWithString:
          [readerMacroStack objectAtIndex:0]]];
        
        [readerMacroStack removeObjectAtIndex:0];
    }
    
    [self openListCell];
}

- (void) addAtom:(id)atom
{
    ParserDebug(@"addAtom: depth = %d  atom: %@", depth, [atom stringValue]);
    
    while ([readerMacroStack count] > 0) {
        ParserDebug(@"  addAtom: readerMacro");
        [self openListCell];
        ++readerMacroDepth[depth];
        ParserDebug(@"  addAtom: ++RMD[%d] = %d", depth, readerMacroDepth[depth]);
        [self addAtomCell:
         [symbolTable symbolWithString:[readerMacroStack objectAtIndex:0]]];
        
        [readerMacroStack removeObjectAtIndex:0];
    }
    
    [self addAtomCell:atom];
    
    while (readerMacroDepth[depth] > 0) {
        --readerMacroDepth[depth];
        ParserDebug(@"  addAtom: --RMD[%d] = %d", depth, readerMacroDepth[depth]);
        [self closeList];
    }
}

- (void) closeListCell
{
    ParserDebug(@"closeListCell: depth = %d", depth);
    
    --depth;
    
    if (addToCar) {
        [current setCar:[NSNull null]];
    }
    else {
        [current setCdr:[NSNull null]];
        current = [stack pop];
    }
    addToCar = false;
    
    while (readerMacroDepth[depth] > 0) {
        --readerMacroDepth[depth];
        ParserDebug(@"  closeListCell: --RMD[%d] = %d", depth, readerMacroDepth[depth]);
        [self closeList];
    }
}

- (void) closeList
{
    ParserDebug(@"closeList: depth = %d", depth);
    
    [self closeListCell];
}

-(void) openReaderMacro:(NSString*) operator
{
    [readerMacroStack addObject:operator];
}

-(void) quoteNextElement
{
    [self openReaderMacro:@"quote"];
}

-(void) quasiquoteNextElement
{
    [self openReaderMacro:@"quasiquote"];
}

-(void) quasiquoteEvalNextElement
{
    [self openReaderMacro:@"quasiquote-eval"];
}

-(void) quasiquoteSpliceNextElement
{
    [self openReaderMacro:@"quasiquote-splice"];
}

int nu_octal_digit_value(unichar c)
{
    int x = (c - '0');
    if ((x >= 0) && (x <= 7))
        return x;
    [NSException raise:@"NuParseError" format:@"invalid octal character: %C", c];
    return 0;
}

unichar nu_hex_digit_value(unichar c)
{
    int x = (c - '0');
    if ((x >= 0) && (x <= 9))
        return x;
    x = (c - 'A');
    if ((x >= 0) && (x <= 5))
        return x + 10;
    x = (c - 'a');
    if ((x >= 0) && (x <= 5))
        return x + 10;
    [NSException raise:@"NuParseError" format:@"invalid hex character: %C", c];
    return 0;
}

unichar nu_octal_digits_to_unichar(unichar c0, unichar c1, unichar c2)
{
    return nu_octal_digit_value(c0)*64 + nu_octal_digit_value(c1)*8 + nu_octal_digit_value(c2);
}

unichar nu_hex_digits_to_unichar(unichar c1, unichar c2)
{
    return nu_hex_digit_value(c1)*16 + nu_hex_digit_value(c2);
}

unichar nu_unicode_digits_to_unichar(unichar c1, unichar c2, unichar c3, unichar c4)
{
    unichar value = nu_hex_digit_value(c1)*4096 + nu_hex_digit_value(c2)*256 + nu_hex_digit_value(c3)*16 + nu_hex_digit_value(c4);
    return value;
}

NSUInteger nu_parse_escape_sequences(NSString *string, NSUInteger i, NSUInteger imax, NSMutableString *partial)
{
    i++;
    unichar c = [string characterAtIndex:i];
    switch(c) {
        case 'n': [partial appendCharacter:0x0a]; break;
        case 'r': [partial appendCharacter:0x0d]; break;
        case 'f': [partial appendCharacter:0x0c]; break;
        case 't': [partial appendCharacter:0x09]; break;
        case 'b': [partial appendCharacter:0x08]; break;
        case 'a': [partial appendCharacter:0x07]; break;
        case 'e': [partial appendCharacter:0x1b]; break;
        case 's': [partial appendCharacter:0x20]; break;
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
        {
            // octal. expect two more digits (\nnn).
            if (imax < i+2) {
                [NSException raise:@"NuParseError" format:@"not enough characters for octal constant"];
            }
            char c1 = [string characterAtIndex:++i];
            char c2 = [string characterAtIndex:++i];
            [partial appendCharacter:nu_octal_digits_to_unichar(c, c1, c2)];
            break;
        }
        case 'x':
        {
            // hex. expect two more digits (\xnn).
            if (imax < i+2) {
                [NSException raise:@"NuParseError" format:@"not enough characters for hex constant"];
            }
            char c1 = [string characterAtIndex:++i];
            char c2 = [string characterAtIndex:++i];
            [partial appendCharacter:nu_hex_digits_to_unichar(c1, c2)];
            break;
        }
        case 'u':
        {
            // unicode. expect four more digits (\unnnn)
            if (imax < i+4) {
                [NSException raise:@"NuParseError" format:@"not enough characters for unicode constant"];
            }
            char c1 = [string characterAtIndex:++i];
            char c2 = [string characterAtIndex:++i];
            char c3 = [string characterAtIndex:++i];
            char c4 = [string characterAtIndex:++i];
            [partial appendCharacter:nu_unicode_digits_to_unichar(c1, c2, c3, c4)];
            break;
        }
        case 'c': case 'C':
        {
            // control character.  Unsupported, fall through to default.
        }
        case 'M':
        {
            // meta character. Unsupported, fall through to default.
        }
        default:
            [partial appendCharacter:c];
    }
    return i;
}

-(id) parse:(NSString*)string
{
    if (!string) return [NSNull null];            // don't crash, at least.
    
    column = 0;
    if (state != PARSE_REGEX)
        [partial setString:@""];
    else
        [partial autorelease];
    
    NSUInteger i = 0;
    NSUInteger imax = [string length];
    for (i = 0; i < imax; i++) {
        column++;
        unichar stri = [string characterAtIndex:i];
        switch (state) {
            case PARSE_NORMAL:
                switch(stri) {
                    case '(':
                        ParserDebug(@"Parser: (  %d on line %d", column, linenum);
                        [opens push:[NSNumber numberWithInt:column]];
                        parens++;
                        if ([partial length] == 0) {
                            [self openList];
                        }
                        break;
                    case ')':
                        ParserDebug(@"Parser: )  %d on line %d", column, linenum);
                        [opens pop];
                        parens--;
                        if (parens < 0) parens = 0;
                        if ([partial length] > 0) {
                            [self addAtom:atomWithString(partial, symbolTable)];
                            [partial setString:@""];
                        }
                        if (depth > 0) {
                            [self closeList];
                        }
                        break;
                    case '"':
                    {
                        state = PARSE_STRING;
                        parseEscapes = YES;
                        [partial setString:@""];
                        break;
                    }
                    case '-':
                    case '+':
                    {
                        if ((i+1 < imax) && ([string characterAtIndex:i+1] == '"')) {
                            state = PARSE_STRING;
                            parseEscapes = (stri == '+');
                            [partial setString:@""];
                            i++;
                        }
                        else {
                            [partial appendCharacter:stri];
                        }
                        break;
                    }
                    case '/':
                    {
                        if (i+1 < imax) {
                            unichar nextc = [string characterAtIndex:i+1];
                            if (nextc == ' ') {
                                [partial appendCharacter:stri];
                            }
                            else {
                                state = PARSE_REGEX;
                                [partial setString:@""];
                                [partial appendCharacter:'/'];
                            }
                        }
                        else {
                            [partial appendCharacter:stri];
                        }
                        break;
                    }
                    case ':':
                        [partial appendCharacter:':'];
                        [self addAtom:atomWithString(partial, symbolTable)];
                        [partial setString:@""];
                        break;
                    case '\'':
                    {
                        // try to parse a character literal.
                        // if that doesn't work, then interpret the quote as the quote operator.
                        bool isACharacterLiteral = false;
                        int characterLiteralValue;
                        if (i + 2 < imax) {
                            if ([string characterAtIndex:i+1] != '\\') {
                                if ([string characterAtIndex:i+2] == '\'') {
                                    isACharacterLiteral = true;
                                    characterLiteralValue = [string characterAtIndex:i+1];
                                    i = i + 2;
                                }
                                else if ((i + 5 < imax) &&
                                         isalnum([string characterAtIndex:i+1]) &&
                                         isalnum([string characterAtIndex:i+2]) &&
                                         isalnum([string characterAtIndex:i+3]) &&
                                         isalnum([string characterAtIndex:i+4]) &&
                                         ([string characterAtIndex:i+5] == '\'')) {
                                    characterLiteralValue =
                                    ((([string characterAtIndex:i+1]*256
                                       + [string characterAtIndex:i+2])*256
                                      + [string characterAtIndex:i+3])*256
                                     + [string characterAtIndex:i+4]);
                                    isACharacterLiteral = true;
                                    i = i + 5;
                                }
                            }
                            else {
                                // look for an escaped character
                                NSUInteger newi = nu_parse_escape_sequences(string, i+1, imax, partial);
                                if ([partial length] > 0) {
                                    isACharacterLiteral = true;
                                    characterLiteralValue = [partial characterAtIndex:0];
                                    [partial setString:@""];
                                    i = newi;
                                    // make sure that we have a closing single-quote
                                    if ((i + 1 < imax) && ([string characterAtIndex:i+1] == '\'')) {
                                        i = i + 1;// move past the closing single-quote
                                    }
                                    else {
                                        [NSException raise:@"NuParseError" format:@"missing close quote from character literal"];
                                    }
                                }
                            }
                        }
                        if (isACharacterLiteral) {
                            [self addAtom:[NSNumber numberWithInt:characterLiteralValue]];
                        }
                        else {
                            [self quoteNextElement];
                        }
                        break;
                    }
                    case '`':
                    {
                        [self quasiquoteNextElement];
                        break;
                    }
                    case ',':
                    {
                        if ((i + 1 < imax) && ([string characterAtIndex:i+1] == '@')) {
                            [self quasiquoteSpliceNextElement];
                            i = i + 1;
                        }
                        else {
                            [self quasiquoteEvalNextElement];
                        }
                        break;
                    }
                    case '\n':                    // end of line
                        column = 0;
                        linenum++;
                    case ' ':                     // end of token
                    case '\r':
                    case '\t':
                    case 0:                       // end of string
                        if ([partial length] > 0) {
                            [self addAtom:atomWithString(partial, symbolTable)];
                            [partial setString:@""];
                        }
                        break;
                    case ';':
                    case '#':
                        if ([partial length] > 0) {
                            NuSymbol *symbol = [symbolTable symbolWithString:partial];
                            [self addAtom:symbol];
                            [partial setString:@""];
                        }
                        state = PARSE_COMMENT;
                        break;
                    case '<':
                        if ((i+3 < imax) && ([string characterAtIndex:i+1] == '<')
                            && (([string characterAtIndex:i+2] == '-') || ([string characterAtIndex:i+2] == '+'))) {
                            // parse a here string
                            state = PARSE_HERESTRING;
                            parseEscapes = ([string characterAtIndex:i+2] == '+');
                            // get the tag to match
                            NSUInteger j = i+3;
                            while ((j < imax) && ([string characterAtIndex:j] != '\n')) {
                                j++;
                            }
                            [pattern release];
                            pattern = [[string substringWithRange:NSMakeRange(i+3, j-(i+3))] retain];
                            //NSLog(@"herestring pattern: %@", pattern);
                            [partial setString:@""];
                            // skip the newline
                            i = j;
                            //NSLog(@"parsing herestring that ends with %@ from %@", pattern, [string substringFromIndex:i]);
                            hereString = nil;
                            hereStringOpened = true;
                            break;
                        }
                        // if this is not a here string, fall through to the general handler
                    default:
                        [partial appendCharacter:stri];
                }
                break;
            case PARSE_HERESTRING:
                //NSLog(@"pattern %@", pattern);
                if ((stri == [pattern characterAtIndex:0]) &&
                    (i + [pattern length] < imax) &&
                    ([pattern isEqual:[string substringWithRange:NSMakeRange(i, [pattern length])]])) {
                    // everything up to here is the string
                    NSString *string = [[[NSString alloc] initWithString:partial] autorelease];
                    [partial setString:@""];
                    if (!hereString)
                        hereString = [[[NSMutableString alloc] init] autorelease];
                    else
                        [hereString appendString:@"\n"];
                    [hereString appendString:string];
                    if (hereString == nil)
                        hereString = [NSMutableString string];
                    //NSLog(@"got herestring **%@**", hereString);
                    [self addAtom:hereString];
                    // to continue, set i to point to the next character after the tag
                    i = i + [pattern length] - 1;
                    //NSLog(@"continuing parsing with:%s", &str[i+1]);
                    //NSLog(@"ok------------");
                    state = PARSE_NORMAL;
                    start = -1;
                }
                else {
                    if (parseEscapes && (stri == '\\')) {
                        // parse escape sequencs in here strings
                        i = nu_parse_escape_sequences(string, i, imax, partial);
                    }
                    else {
                        [partial appendCharacter:stri];
                    }
                }
                break;
            case PARSE_STRING:
                switch(stri) {
                    case '"':
                    {
                        state = PARSE_NORMAL;
                        NSString *string = [NSString stringWithString:partial];
                        //NSLog(@"parsed string:%@:", string);
                        [self addAtom:string];
                        [partial setString:@""];
                        break;
                    }
                    case '\n':
                    {
                        column = 0;
                        linenum++;
                        NSString *string = [[NSString alloc] initWithString:partial];
                        [NSException raise:@"NuParseError" format:@"partial string (terminated by newline): %@", string];
                        [partial setString:@""];
                        break;
                    }
                    case '\\':
                    {                             // parse escape sequences in strings
                        if (parseEscapes) {
                            i = nu_parse_escape_sequences(string, i, imax, partial);
                        }
                        else {
                            [partial appendCharacter:stri];
                        }
                        break;
                    }
                    default:
                    {
                        [partial appendCharacter:stri];
                    }
                }
                break;
            case PARSE_REGEX:
                switch(stri) {
                    case '/':                     // that's the end of it
                    {
                        [partial appendCharacter:'/'];
                        i++;
                        // add any remaining option characters
                        while (i < imax) {
                            unichar nextc = [string characterAtIndex:i];
                            if ((nextc >= 'a') && (nextc <= 'z')) {
                                [partial appendCharacter:nextc];
                                i++;
                            }
                            else {
                                i--;              // back up to revisit this character
                                break;
                            }
                        }
                        [self addAtom:regexWithString(partial)];
                        [partial setString:@""];
                        state = PARSE_NORMAL;
                        break;
                    }
                    case '\\':
                    {
                        [partial appendCharacter:stri];
                        i++;
                        [partial appendCharacter:[string characterAtIndex:i]];
                        break;
                    }
                    default:
                    {
                        [partial appendCharacter:stri];
                    }
                }
                break;
            case PARSE_COMMENT:
                switch(stri) {
                    case '\n':
                    {
                        if (!comments) comments = [[NSMutableString alloc] init];
                        else [comments appendString:@"\n"];
                        [comments appendString:[[[NSString alloc] initWithString:partial] autorelease]];
                        [partial setString:@""];
                        column = 0;
                        linenum++;
                        state = PARSE_NORMAL;
                        break;
                    }
                    default:
                    {
                        [partial appendCharacter:stri];
                    }
                }
        }
    }
    // close off anything that is still being scanned.
    if (state == PARSE_NORMAL) {
        if ([partial length] > 0) {
            [self addAtom:atomWithString(partial, symbolTable)];
        }
        [partial setString:@""];

        // close off open lists
        while (depth > 0) {
            if (parens > 0) {
                [opens pop];
                parens--;
            }
            [self closeList];
        }
    
    }
    else if (state == PARSE_COMMENT) {
        if (!comments) comments = [[NSMutableString alloc] init];
        [comments appendString:[[[NSString alloc] initWithString:partial] autorelease]];
        [partial setString:@""];
        column = 0;
        linenum++;
        state = PARSE_NORMAL;
    }
    else if (state == PARSE_STRING) {
        [NSException raise:@"NuParseError" format:@"partial string (terminated by newline): %@", partial];
    }
    else if (state == PARSE_HERESTRING) {
        if (hereStringOpened) {
            hereStringOpened = false;
        }
        else {
            if (hereString) {
                [hereString appendString:@"\n"];
            }
            else {
                hereString = [[NSMutableString alloc] init];
            }
            [hereString appendString:partial];
            [partial setString:@""];
        }
    }
    else if (state == PARSE_REGEX) {
        // we stay in this state and leave the regex open.
        [partial appendCharacter:'\n'];
        [partial retain];
    }
    if ([self incomplete]) {
        return [NSNull null];
    }
    else {
        NuCell *expressions = root;
        root = nil;
        [self reset];
        [expressions autorelease];
        return expressions;
    }
}

- (id) parse:(NSString *)string asIfFromFilename:(NSString *) name;
{
    [self setFilename:name];
    id result = [self parse:string];
    return result;
}

- (void) newline
{
    linenum++;
}

- (id) eval: (id) code
{
    return [code evalWithContext:context];
}

- (id) valueForKey:(NSString *)string
{
    return [self eval:[self parse:string]];
}

- (void) setValue:(id)value forKey:(NSString *)string
{
    [context setObject:value forKey:[symbolTable symbolWithString:string]];
}

- (NSString *) parseEval:(NSString *)string
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NuCell *expressions = [self parse:string];
    id result = [[expressions evalWithContext:context] stringValue];
    [result retain];
    [pool drain];
    [result autorelease];
    return result;
}

@end

#pragma mark - NuPointer.m

@interface NuPointer () 
{
    void *pointer;
    NSString *typeString;
    bool thePointerIsMine;
}
@end

@implementation NuPointer

- (id) init
{
    if ((self = [super init])) {
        pointer = 0;
        typeString = nil;
        thePointerIsMine = NO;
    }
    return self;
}

- (void *) pointer {return pointer;}

- (void) setPointer:(void *) p
{
    pointer = p;
}

- (NSString *) typeString {return typeString;}

- (id) object
{
    return pointer;
}

- (void) setTypeString:(NSString *) s
{
    [s retain];
    [typeString release];
    typeString = s;
}

- (void) allocateSpaceForTypeString:(NSString *) s
{
    if (thePointerIsMine)
        free(pointer);
    [self setTypeString:s];
    const char *type = [s cStringUsingEncoding:NSUTF8StringEncoding];
    while (*type && (*type != '^'))
        type++;
    if (*type)
        type++;
    //NSLog(@"allocating space for type %s", type);
    pointer = value_buffer_for_objc_type(type);
    thePointerIsMine = YES;
}

- (void) dealloc
{
    [typeString release];
    if (thePointerIsMine)
        free(pointer);
    [super dealloc];
}

- (id) value
{
    const char *type = [typeString cStringUsingEncoding:NSUTF8StringEncoding];
    while (*type && (*type != '^'))
        type++;
    if (*type)
        type++;
    //NSLog(@"getting value for type %s", type);
    return get_nu_value_from_objc_value(pointer, type);
}

@end

#pragma mark - NuProfiler.h

@interface NuProfileStackElement : NSObject
{
@public
    NSString *name;
    uint64_t start;
    NuProfileStackElement *parent;
}

@end

@interface NuProfileTimeSlice : NSObject
{
@public
    float time;
    int count;
}

@end

@implementation NuProfileStackElement

- (NSString *) name {return name;}
- (uint64_t) start {return start;}
- (NuProfileStackElement *) parent {return parent;}

- (NSString *) description
{
    return [NSString stringWithFormat:@"name:%@ start:%f", name, start];
}

@end

@implementation NuProfileTimeSlice

- (float) time {return time;}
- (int) count {return count;}

- (NSString *) description
{
    return [NSString stringWithFormat:@"time:%f count:%d", time, count];
}

@end

@interface NuProfiler ()
{
    NSMutableDictionary *sections;
    NuProfileStackElement *stack;
}
@end

@implementation NuProfiler

NuProfiler *defaultProfiler = nil;

+ (NuProfiler *) defaultProfiler
{
    if (!defaultProfiler)
        defaultProfiler = [[NuProfiler alloc] init];
    return defaultProfiler;
}

- (NuProfiler *) init
{
    self = [super init];
    sections = [[NSMutableDictionary alloc] init];
    stack = nil;
    return self;
}

- (void) start:(NSString *) name
{
    NuProfileStackElement *stackElement = [[NuProfileStackElement alloc] init];
    stackElement->name = [name retain];
    stackElement->start = mach_absolute_time();
    stackElement->parent = stack;
    stack = stackElement;
}

- (void) stop
{
    if (stack) {
        uint64_t current_time = mach_absolute_time();
        uint64_t time_delta = current_time - stack->start;
        struct mach_timebase_info info;
        mach_timebase_info(&info);
        float timeDelta = 1e-9 * time_delta * (double) info.numer / info.denom;
        //NSNumber *delta = [NSNumber numberWithFloat:timeDelta];
        NuProfileTimeSlice *entry = [sections objectForKey:stack->name];
        if (!entry) {
            entry = [[[NuProfileTimeSlice alloc] init] autorelease];
            entry->count = 1;
            entry->time = timeDelta;
            [sections setObject:entry forKey:stack->name];
        }
        else {
            entry->count++;
            entry->time += timeDelta;
        }
        [stack->name release];
        NuProfileStackElement *top = stack;
        stack = stack->parent;
        [top release];
    }
}

- (NSMutableDictionary *) sections
{
    return sections;
}

- (void) reset
{
    [sections removeAllObjects];
    while (stack) {
        NuProfileStackElement *top = stack;
        stack = stack->parent;
        [top release];
    }
}

@end

#pragma mark - NuProperty.m

@interface NuProperty () 
{
    objc_property_t p;
}
@end

@implementation NuProperty

+ (NuProperty *) propertyWithProperty:(objc_property_t) property {
    return [[[self alloc] initWithProperty:property] autorelease];
}

- (id) initWithProperty:(objc_property_t) property 
{
    if ((self = [super init])) {
        p = property;
    }
    return self;
}

- (NSString *) name 
{
    return [NSString stringWithCString:property_getName(p) encoding:NSUTF8StringEncoding];
} 

@end

#pragma mark - NuReference.m

@interface NuReference ()
{
    id *pointer;
    bool thePointerIsMine;
}
@end

@implementation NuReference

- (id) init
{
    if ((self = [super init])) {
        pointer = 0;
        thePointerIsMine = false;
    }
    return self;
}

- (id) value {return pointer ? *pointer : nil;}

- (void) setValue:(id) v
{
    if (!pointer) {
        pointer = (id *) malloc (sizeof (id));
        *pointer = nil;
        thePointerIsMine = true;
    }
    [v retain];
    [(*pointer) release];
    (*pointer)  = v;
}

- (void) setPointer:(id *) p
{
    if (thePointerIsMine) {
        free(pointer);
        thePointerIsMine = false;
    }
    pointer = p;
}

- (id *) pointerToReferencedObject
{
    if (!pointer) {
        pointer = (id *) malloc (sizeof (id));
        *pointer = nil;
        thePointerIsMine = true;
    }
    return pointer;
}

- (void) retainReferencedObject
{
    [(*pointer) retain];
}

- (void) dealloc
{
    if (thePointerIsMine)
        free(pointer);
    [super dealloc];
}

@end




#pragma mark - NuSuper.m
@interface NuSuper ()
{
    id object;
    Class class;
}
@end

@implementation NuSuper

- (NuSuper *) initWithObject:(id) o ofClass:(Class) c
{
    if ((self = [super init])) {
        object = o; // weak reference
        class = c; // weak reference
    }
    return self;
}

+ (NuSuper *) superWithObject:(id) o ofClass:(Class) c
{
    return [[[self alloc] initWithObject:o ofClass:c] autorelease];
}

- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    // By themselves, Objective-C objects evaluate to themselves.
    if (!cdr || (cdr == [NSNull null]))
        return object;
    
    //NSLog(@"messaging super with %@", [cdr stringValue]);
    // But when they're at the head of a list, the list is converted to a message and sent to the object
    
    NSMutableArray *args = [[NSMutableArray alloc] init];
    id cursor = cdr;
    id selector = [cursor car];
    NSMutableString *selectorString = [NSMutableString stringWithString:[selector stringValue]];
    cursor = [cursor cdr];
    while (cursor && (cursor != [NSNull null])) {
        [args addObject:[[cursor car] evalWithContext:context]];
        cursor = [cursor cdr];
        if (cursor && (cursor != [NSNull null])) {
            [selectorString appendString:[[cursor car] stringValue]];
            cursor = [cursor cdr];
        }
    }
    SEL sel = sel_getUid([selectorString cStringUsingEncoding:NSUTF8StringEncoding]);
    
    // we're going to send the message to the handler of its superclass instead of one defined for its class.
    Class c = class_getSuperclass(class);
    Method m = class_getInstanceMethod(c, sel);
    if (!m) m = class_getClassMethod(c, sel);
    
    id result;
    if (m) {
        result = nu_calling_objc_method_handler(object, m, args);
    }
    else {
        NSLog(@"can't find function in superclass!");
        result = self;
    }
    [args release];
    return result;
}

@end

#pragma mark - NuSwizzles.m

@interface NSCFDictionarySwizzles : NSObject {}
@end

@implementation NSCFDictionarySwizzles

- (void)nuSetObject:(id)anObject forKey:(id)aKey
{
    [self nuSetObject:((anObject == nil) ? (id)[NSNull null] : anObject) forKey:aKey];
}

@end

@interface NSCFArraySwizzles : NSObject {}
@end

@implementation NSCFArraySwizzles

- (void)nuAddObject:(id)anObject
{
    [self nuAddObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

- (void)nuInsertObject:(id)anObject atIndex:(int)index
{
    [self nuInsertObject:((anObject == nil) ? (id)[NSNull null] : anObject) atIndex:index];
}

- (void)nuReplaceObjectAtIndex:(int)index withObject:(id)anObject
{
    [self nuReplaceObjectAtIndex:index withObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

@end

@interface NSCFSetSwizzles : NSObject {}
@end

@implementation NSCFSetSwizzles

- (void)nuAddObject:(id)anObject
{
    [self nuAddObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

@end

void nu_swizzleContainerClasses()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Class NSCFDictionary = NSClassFromString(@"NSCFDictionary");
    Class NSCFArray = NSClassFromString(@"NSCFArray");
    Class NSCFSet = NSClassFromString(@"NSCFSet");
    [NSCFDictionary include:[NuClass classWithName:@"NSCFDictionarySwizzles"]];
    [NSCFArray include:[NuClass classWithName:@"NSCFArraySwizzles"]];
    [NSCFSet include:[NuClass classWithName:@"NSCFSetSwizzles"]];
    [NSCFDictionary exchangeInstanceMethod:@selector(setObject:forKey:) withMethod:@selector(nuSetObject:forKey:)];
    [NSCFArray exchangeInstanceMethod:@selector(addObject:) withMethod:@selector(nuAddObject:)];
    [NSCFArray exchangeInstanceMethod:@selector(insertObject:atIndex:) withMethod:@selector(nuInsertObject:atIndex:)];
    [NSCFArray exchangeInstanceMethod:@selector(replaceObjectAtIndex:withObject:) withMethod:@selector(nuReplaceObjectAtIndex:withObject:)];
    [NSCFSet exchangeInstanceMethod:@selector(addObject:) withMethod:@selector(nuAddObject:)];
    [pool drain];
}

#pragma mark - NuSymbol.m

@interface NuSymbol ()
{
    NuSymbolTable *table;
    id value;
@public                                       // only for use by the symbol table
    bool isLabel;
    bool isGensym;                                // in macro evaluation, symbol is replaced with an automatically-generated unique symbol.
    NSString *stringValue;			  // let's keep this for efficiency
}
@end

@interface NuSymbolTable ()
{
    NSMutableDictionary *symbol_table;
}
@end

NuSymbolTable *sharedSymbolTable = 0;

@implementation NuSymbolTable
@synthesize builtin = _builtin;

+ (NuSymbolTable *) sharedSymbolTable
{
    if (!sharedSymbolTable) {
        sharedSymbolTable = [[self alloc] init];
    }
    return sharedSymbolTable;
}

- (void) dealloc
{
    NSLog(@"WARNING: deleting a symbol table. Leaking stored symbols.");
    [super dealloc];
}

// Designated initializer
- (NuSymbol *) symbolWithString:(NSString *)string
{
    if (!symbol_table) symbol_table = [[NSMutableDictionary alloc] init];
    
    // If the symbol is already in the table, return it.
    NuSymbol *symbol;
    symbol = [symbol_table objectForKey:string];
    if (symbol) {
        return symbol;
    }
    
    // If not, create it. Don't autorelease it; it is owned by the table.
    symbol = [[NuSymbol alloc] init];             // keep construction private
    symbol->stringValue = [string copy];
    
    const char *cstring = [string cStringUsingEncoding:NSUTF8StringEncoding];
    NSUInteger len = strlen(cstring);
    symbol->isLabel = (cstring[len - 1] == ':');
    symbol->isGensym = (len > 2) && (cstring[0] == '_') && (cstring[1] == '_');
    
    // Put the new symbol in the symbol table and return it.
    [symbol_table setObject:symbol forKey:string];
    return symbol;
}

- (NuSymbol *) lookup:(NSString *) string
{
    return [symbol_table objectForKey:string];
}

- (NSDictionary *)dict { return symbol_table; }

- (NSArray *) all
{
    return [symbol_table allValues];
}

- (void) removeSymbol:(NuSymbol *) symbol
{
    [symbol_table removeObjectForKey:[symbol stringValue]];
}

- (id)builtinForKeyPath:(id)lst
{
    if (!self.builtin)
        return nil;
    id cursor = self.builtin;
    for (id key in lst) {
        cursor = [(NSMutableDictionary *)cursor objectForKey:key];
    }
    return cursor;
}

- (void)setBuiltin:(id)obj forKeyPath:(id)lst
{
    if (!self.builtin) {
        self.builtin = [[[NSMutableDictionary alloc] init] autorelease];
    }
    int n = [lst count];
    id cursor = self.builtin;
    int i = 0;
    for (id key in lst) {
        i++;
        if (i == n) {
            [(NSMutableDictionary *)cursor setObject:obj forKey:key];
        } else {
            id val = [(NSMutableDictionary *)cursor objectForKey:key];
            if (!val) {
                val = [[[NSMutableDictionary alloc] init] autorelease];
                [(NSMutableDictionary *)cursor setObject:val forKey:key];
            }
            cursor = val;
        }
    }
}

@end

@implementation NuSymbol

- (void) dealloc
{
    [stringValue release];
    [super dealloc];
}

- (BOOL) isEqual: (NuSymbol *)other
{
    return (self == other) ? 1l : 0l;
}

- (id) value
{
    return value;
}

- (void) setValue:(id)v
{
    [v retain];
    [value release];
    value = v;
}

- (NSString *) description
{
    return stringValue;
}

- (NSString *) stringValue
{
    return stringValue;
}

- (int) intValue
{
    return (value == [NSNull null]) ? 0 : 1;
}

- (bool) isGensym
{
    return isGensym;
}

- (bool) isLabel
{
    return isLabel;
}

- (NSString *) labelName
{
    if (isLabel)
        return [[self stringValue] substringToIndex:[[self stringValue] length] - 1];
    else
        return [self stringValue];
}

- (id) evalWithContext:(NSMutableDictionary *)context
{
    
    char c = (char) [[self stringValue] characterAtIndex:0];
    // If the symbol is a class instance variable, find "self" and ask it for the ivar value.
    if (c == '@') {
        NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
        id object = [context lookupObjectForKey:[symbolTable symbolWithString:@"self"]];
        if (!object) return [NSNull null];
        id ivarName = [[self stringValue] substringFromIndex:1];
        id result = [object valueForIvar:ivarName];
        return result ? result : (id) [NSNull null];
    }
    
    // Next, try to find the symbol in the local evaluation context.
    id valueInContext = [context lookupObjectForKey:self];
    if (valueInContext)
        return valueInContext;
    
    // Next, return the global value assigned to the value.
    if (value)
        return value;
    
    value = Nu__null;
//    NSLog(@"fileContents symbol %@", [self stringValue]);
    id namespaceValue = nu_symbol_from_namespaces([self stringValue]);
    if (namespaceValue) {
        value = [namespaceValue retain];
        return value;
    }
        
    // If the symbol is a label (ends in ':'), then it will evaluate to itself.
    if (isLabel)
        return self;
    
    // If the symbol is still unknown, try to find a class with this name.
    id className = [self stringValue];
    // the symbol should retain its value.
    value = [[NuClass classWithName:className] retain];
    if (value)
        return value;
            
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    
    // Still-undefined symbols throw an exception.
    NSMutableString *errorDescription = [NSMutableString stringWithFormat:@"undefined symbol %@", [self stringValue]];
    id expression = [context lookupObjectForKey:[symbolTable symbolWithString:@"_expression"]];
    if (expression) {
        [errorDescription appendFormat:@" while evaluating expression %@", [expression stringValue]];
        [errorDescription appendFormat:@" at %@:%d", [expression file], [expression line]];
    }
    [NSException raise:@"NuUndefinedSymbol" format:@"%@", errorDescription];
    return [NSNull null];
}

- (NSComparisonResult) compare:(NuSymbol *) anotherSymbol
{
    return [stringValue compare:anotherSymbol->stringValue];
}

- (id) copyWithZone:(NSZone *) zone
{
    // Symbols are unique, so we don't copy them, but we retain them again since copies are automatically retained.
    return [self retain];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[self stringValue]];
}

- (id) initWithCoder:(NSCoder *)coder
{
    [super init];
    [self autorelease];
    return [[[NuSymbolTable sharedSymbolTable] symbolWithString:[coder decodeObject]] retain];
}

@end

@implementation NSNull(Nu)
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id [])buffer count:(NSUInteger)len
{
    return 0;
}

- (bool) atom
{
    return true;
}

- (NSUInteger) length
{
    return 0;
}

- (NSUInteger) count
{
    return 0;
}

- (NSMutableArray *) array
{
    return [NSMutableArray array];
}

- (NSString *)description
{
    return @"nil";
}

- (NSString *) stringValue
{
    return @"nil";
}

- (BOOL) isEqual:(id) other
{
    return ((self == other) || (other == 0)) ? 1l : 0l;
}

- (const char *) cStringUsingEncoding:(NSStringEncoding) encoding
{
    return [[self stringValue] cStringUsingEncoding:encoding];
}

- (id)symbolWithString:(id)str
{
    NSLog(@"NSNull symbolWithString %@", str);
    return [[NuSymbolTable sharedSymbolTable] symbolWithString:str];
}

- (id)lookupObjectForKey:(id)key
{
    NSLog(@"NSNull lookupObjectForKey %@", key);
    return nil;
}

@end



