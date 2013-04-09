#import "Nu.h"
#include <event2/http.h>
#import "ObjectiveChipmunk.h"
#import "JSONKit.h"

id nu_map(id enumerable, id block, Class class)
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id results = [[[class alloc] init] autorelease];
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            id val = [block evalWithArguments:args context:Nu__null];
            [results addObject:val];
        }
        [args release];
        if (![results count])
            return Nu__null;
        return results;
    }
    return Nu__null;
}

id nu_map_pairs(id enumerable, id block, Class class)
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id results = [[[class alloc] init] autorelease];
        id args = [[NuCell alloc] init];
        [args setCdr:[[[NuCell alloc] init] autorelease]];
        id first = nil;
        for (id obj in enumerable) {
            if (!first) {
                first = obj;
                continue;
            }
            [args setCar:first];
            [[args cdr] setCar:obj];
            id val = [block evalWithArguments:args context:Nu__null];
            [results addObject:val];
            first = nil;
        }
        [args release];
        if (![results count])
            return Nu__null;
        return results;
    }
    return Nu__null;
}

id nu_map_with_index(id enumerable, id block, Class class)
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id results = [[[class alloc] init] autorelease];
        id args = [[NuCell alloc] init];
        [args setCdr:[[[NuCell alloc] init] autorelease]];
        int i = 0;
        for (id obj in enumerable) {
            [args setCar:obj];
            [[args cdr] setCar:[NSNumber numberWithInt:i]];
            id val = [block evalWithArguments:args context:Nu__null];
            [results addObject:val];
            i++;
        }
        [args release];
        if (![results count])
            return Nu__null;
        return results;
    }
    return Nu__null;
}

id nu_keep(id enumerable, id block, Class class)
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    id results = [[[class alloc] init] autorelease];
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            if (nu_valueIsTrue([block evalWithArguments:args context:Nu__null])) {
                [results addObject:obj];
            }
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if ([obj isEqual:block]) {
                [results addObject:obj];
            }
        }
    }
    if (![results count])
        return Nu__null;
    return results;
}

id nu_remove(id enumerable, id block, Class class)
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    id results = [[[class alloc] init] autorelease];
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            if (!nu_valueIsTrue([block evalWithArguments:args context:Nu__null])) {
                [results addObject:obj];
            }
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if (![obj isEqual:block]) {
                [results addObject:obj];
            }
        }
    }
    if (![results count])
        return Nu__null;
    return results;
}

id nu_any(id enumerable, id block)
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            id val = [block evalWithArguments:args context:Nu__null];
            if (nu_valueIsTrue(val)) {
                [args release];
                return obj;
            }
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if ([block isEqual:obj]) {
                return obj;
            }
        }
    }
    return Nu__null;
}


id nu_match(id enumerable, id block)
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            id val = [block evalWithArguments:args context:Nu__null];
            if (nu_valueIsTrue(val)) {
                [args release];
                return val;
            }
        }
        [args release];
    }
    return Nu__null;
}

id nu_all(id enumerable, id block)
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            if (!nu_valueIsTrue([block evalWithArguments:args context:Nu__null])) {
                [args release];
                return nil;
            }
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if (![obj isEqual:block]) {
                return nil;
            }
        }
    }
    return Nu__t;
}

id nu_some(id enumerable, id block)
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            if (nu_valueIsTrue([block evalWithArguments:args context:Nu__null])) {
                [args release];
                return Nu__t;
            }
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if ([obj isEqual:block]) {
                return Nu__t;
            }
        }
    }
    return Nu__null;
}

id nu_position(id enumerable, id block)
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    int index = 0;
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            if (nu_valueIsTrue([block evalWithArguments:args context:Nu__null])) {
                [args release];
                return [NSNumber numberWithInt:index];
            }
            index++;
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if ([obj isEqual:block]) {
                return [NSNumber numberWithInt:index];
            }
            index++;
        }
    }
    return Nu__null;
}

id nu_trues_for_list(id enumerable, id block)
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    id head = nil, tail = nil;
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            id val = [block evalWithArguments:args context:Nu__null];
            if (nu_valueIsTrue(val)) {
                tail = nucons1(tail, val);
                if (!head)
                    head = tail;
            }
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if ([obj isEqual:block]) {
                tail = nucons1(tail, obj);
                if (!head)
                    head = tail;
            }
        }
    }
    return head;
}

id nu_trues(id enumerable, id block, Class class)
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    id results = [[[class alloc] init] autorelease];
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in enumerable) {
            [args setCar:obj];
            id val = [block evalWithArguments:args context:Nu__null];
            if (nu_valueIsTrue(val)) {
                [results addObject:val];
            }
        }
        [args release];
    } else {
        for (id obj in enumerable) {
            if (!nu_valueIsNull(obj)) {
                [results addObject:obj];
            }
        }
    }
    if (![results count])
        return Nu__null;
    return results;
}

@interface NuCell ()
{
    id car;
    id cdr;
    NSString *file;
    int line;
}
@end

@implementation NuCell

- (CGFloat)x
{
    return [car floatValue];
}

- (CGFloat)y
{
    id obj = [self nth:1];
    return (nu_valueIsNull(obj)) ? 0.0 : [obj floatValue];
}

- (CGFloat)w
{
    if ([self count] < 4) {
        return [self x];
    }
    id obj = [self nth:2];
    return (nu_valueIsNull(obj)) ? 0.0 : [obj floatValue];
}

- (CGFloat)h
{
    if ([self count] < 4) {
        return [self y];
    }
    id obj = [self nth:3];
    return (nu_valueIsNull(obj)) ? 0.0 : [obj floatValue];
}

- (cpBB)cpBBValue
{
    if ([self count] != 4)
        return cpBBNew(0.0, 0.0, 0.0, 0.0);
    return cpBBNew([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue], [[self objectAtIndex:2] floatValue], [[self objectAtIndex:3] floatValue]);
}

- (cpVect)cpVectValue
{
    if ([self count] != 2)
        return cpv(0.0, 0.0);
    return cpv([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue]);
}

- (CGPoint)pointValue
{
    if ([self count] != 2)
        return CGPointMake(0.0, 0.0);
    return CGPointMake([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue]);
}

- (NSRange)rangeValue
{
    NSRange r;
    if ([self count] != 2) {
        r.length = 0;
        r.location = 0;
        return r;
    }
    r.length = [[self objectAtIndex:0] unsignedIntegerValue];
    r.location = [[self objectAtIndex:1] unsignedIntegerValue];
    return r;
}

- (CGRect)rectValue
{
    if ([self count] != 4)
        return CGRectMake(0.0, 0.0, 0.0, 0.0);
    return CGRectMake([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue], [[self objectAtIndex:2] floatValue], [[self objectAtIndex:3] floatValue]);
}

- (CGSize)sizeValue
{
    if ([self count] != 2)
        return CGSizeMake(0.0, 0.0);
    return CGSizeMake([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue]);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id [])buffer count:(NSUInteger)len
{
    NuCell **ptr = &state->extra[1];
    if (state->state == 0) {
        state->mutationsPtr = &state->extra[0];
        *ptr = self;
        state->state = 1;
    } else {
        *ptr = [*ptr cdr];
    }
    state->itemsPtr = buffer;
    if (!*ptr || (*ptr == Nu__null))
        return 0;
    id obj = [*ptr car];
    if (!obj)
        obj = Nu__null;
    buffer[0] = obj;
    return 1;
}

+ (id) cellWithCar:(id)car cdr:(id)cdr
{
    NuCell *cell = [[self alloc] init];
    [cell setCar:car];
    [cell setCdr:cdr];
    return [cell autorelease];
}

- (id) init
{
    if ((self = [super init])) {
        car = Nu__null;
        cdr = Nu__null;
        file = nil;
        line = -1;
    }
    return self;
}

- (void) dealloc
{
    [car release];
    car = nil;
    [cdr release];
    cdr = nil;
    [file release];
    file = nil;
    [super dealloc];
}

- (bool) atom {return false;}

- (id) car {return car;}

- (id) cdr {return cdr;}

- (void) setCar:(id) c
{
    [c retain];
    [car release];
    car = c;
}

- (void) setCdr:(id) c
{
    [c retain];
    [cdr release];
    cdr = c;
}

// additional accessors, for efficiency (from Nu)
- (id) caar {return [car car];}
- (id) cadr {return [cdr car];}
- (id) cdar {return [car cdr];}
- (id) cddr {return [cdr cdr];}
- (id) caaar {return [[car car] car];}
- (id) caadr {return [[cdr car] car];}
- (id) cadar {return [[car cdr] car];}
- (id) caddr {return [[cdr cdr] car];}
- (id) cdaar {return [[car car] cdr];}
- (id) cdadr {return [[cdr car] cdr];}
- (id) cddar {return [[cdr cdr] car];}
- (id) cdddr {return [[cdr cdr] cdr];}

- (BOOL) isEqual:(id) other
{
    if (nu_objectIsKindOfClass(other, [NuCell class])
        && [[self car] isEqual:[other car]] && [[self cdr] isEqual:[other cdr]]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (id) first
{
    return car;
}

- (id) second
{
    return [cdr car];
}

- (id) third
{
    return [[cdr cdr] car];
}

- (id) fourth
{
    return [[[cdr cdr]  cdr] car];
}

- (id) fifth
{
    return [[[[cdr cdr]  cdr]  cdr] car];
}

- (id) nth:(int) n
{
    if (n < 1)
        return nil;
    id cursor = self;
    for(int i=0; i<n; i++) {
        cursor = [cursor cdr];
        if (nu_valueIsNull(cursor)) {
            return nil;
        }
    }
    return [cursor car];
}

- (id) objectAtIndex:(int) n
{
    if (n < 0)
        return nil;
    else if (n == 0)
        return car;
    id cursor = cdr;
    for (int i = 1; i < n; i++) {
        cursor = [cursor cdr];
        if (cursor == Nu__null) return nil;
    }
    return [cursor car];
}

- (id)handleUnknownMessage:(id)message withContext:(NSMutableDictionary *)context
{
    if (nu_valueIsNull(message))
        return self;
    if (nu_objectIsKindOfClass([message car], [NSNumber class])) {
        int mm = [[message car] intValue];
        if (mm < 0) {
            // if the index is negative, index from the end of the array
            mm += [self length];
        }
        return [self objectAtIndex:mm];
    }
    return Nu__null;
}

- (id) lastObject
{
    id cursor = self;
    while ([cursor cdr] != Nu__null) {
        cursor = [cursor cdr];
    }
    return [cursor car];
}

- (NSMutableString *) stringValue
{
    NuCell *cursor = self;
    NSMutableString *result = [NSMutableString stringWithString:@"("];
    int count = 0;
    while (IS_NOT_NULL(cursor)) {
        if (count > 0)
            [result appendString:@" "];
        count++;
        id item = [cursor car];
        if (nu_objectIsKindOfClass(item, [NuCell class])) {
            [result appendString:[item stringValue]];
        }
        else if (IS_NOT_NULL(item)) {
            if ([item respondsToSelector:@selector(escapedStringRepresentation)]) {
                [result appendString:[item escapedStringRepresentation]];
            }
            else {
                [result appendString:[item description]];
            }
        }
        else {
            [result appendString:@"()"];
        }
        cursor = [cursor cdr];
        // check for dotted pairs
        if (IS_NOT_NULL(cursor) && !nu_objectIsKindOfClass(cursor, [NuCell class])) {
            [result appendString:@" . "];
            if ([cursor respondsToSelector:@selector(escapedStringRepresentation)]) {
                [result appendString:[((id) cursor) escapedStringRepresentation]];
            }
            else {
                [result appendString:[cursor description]];
            }
            break;
        }
    }
    [result appendString:@")"];
    return result;
}

- (NSString *) description
{
    return [self stringValue];
}

- (void) addToException:(NuException*)e value:(id)value
{
    [e addFunction:value lineNumber:[self line] filename:file];
}

- (id) evalWithContext:(NSMutableDictionary *)context
{
    id value = nil;
    id result = nil;
    
    @try
    {
        value = [car evalWithContext:context];
        
        if (NU_LIST_EVAL_BEGIN_ENABLED()) {
            if ((self->line != -1) && (self->file)) {
                NU_LIST_EVAL_BEGIN("fixme", self->line);
            }
            else {
                NU_LIST_EVAL_BEGIN("", 0);
            }
        }
        // to improve error reporting, add the currently-evaluating expression to the context
        [context setObject:self forKey:nusym(@"_expression")];
        
        
        result = [value evalWithArguments:cdr context:context];
        [context setPossiblyNullObject:result forKey:nusym(@"_")];
        
        if (NU_LIST_EVAL_END_ENABLED()) {
            if ((self->line != -1) && (self->file)) {
                NU_LIST_EVAL_END("fixme", self->line);
            }
            else {
                NU_LIST_EVAL_END("", 0);
            }
        }
    }
    @catch (NuException* nuException) {
        [self addToException:nuException value:[car stringValue]];
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
            [self addToException:nuException value:[car stringValue]];
            @throw nuException;
        }
    }
    
    return result;
}

- (id)map:(id)block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id head = nil, tail = nil;
        id args = [[NuCell alloc] init];
        id cursor = self;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            id result = [block evalWithArguments:args context:Nu__null];
            tail = nucons1(tail, result);
            if (!head)
                head = tail;
            cursor = [cursor cdr];
        }
        [args release];
        return head;
    }
    return Nu__null;
}

- (id)mapPairs:(id)block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id head = nil, tail = nil;
        id args = [[NuCell alloc] init];
        [args setCdr:[[[NuCell alloc] init] autorelease]];
        id cursor = self;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            [[args cdr] setCar:[[cursor cdr] car]];
            id result = [block evalWithArguments:args context:Nu__null];
            tail = nucons1(tail, result);
            if (!head)
                head = tail;
            cursor = [[cursor cdr] cdr];
        }
        [args release];
        return head;
    }
    return Nu__null;;
}

- (id)mapWithIndex:(id)block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id head = nil, tail = nil;
        id args = [[NuCell alloc] init];
        [args setCdr:[[[NuCell alloc] init] autorelease]];
        id cursor = self;
        int i = 0;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            [[args cdr] setCar:[NSNumber numberWithInt:i]];
            id result = [block evalWithArguments:args context:Nu__null];
            tail = nucons1(tail, result);
            if (!head)
                head = tail;
            cursor = [cursor cdr];
            i++;
        }
        [args release];
        return head;
    }
    return Nu__null;
}

- (id)any:(id)block { return nu_any(self, block); }
- (id)match:(id)block { return nu_match(self, block); }

- (id)keep:(id)block
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    id head = nil, tail = nil;
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in self) {
            [args setCar:obj];
            if (nu_valueIsTrue([block evalWithArguments:args context:Nu__null])) {
                tail = nucons1(tail, obj);
                if (!head)
                    head = tail;
            }
        }
        [args release];
    } else {
        for (id obj in self) {
            if ([obj isEqual:block]) {
                tail = nucons1(tail, obj);
                if (!head)
                    head = tail;
            }
        }
    }
    return head;
}

- (id)remove:(id)block
{
    BOOL isBlock = nu_objectIsKindOfClass(block, [NuBlock class]);
    id head = nil, tail = nil;
    if (isBlock) {
        id args = [[NuCell alloc] init];
        for (id obj in self) {
            [args setCar:obj];
            if (!nu_valueIsTrue([block evalWithArguments:args context:Nu__null])) {
                tail = nucons1(tail, obj);
                if (!head)
                    head = tail;
            }
        }
        [args release];
    } else {
        for (id obj in self) {
            if (![obj isEqual:block]) {
                tail = nucons1(tail, obj);
                if (!head)
                    head = tail;
            }
        }
    }
    return head;
}


- (id)all:(id)block { return nu_all(self, block); }
- (id)some:(id)block { return nu_some(self, block); }
- (id)position:(id)block { return nu_position(self, block); }
- (id)trues:(id)block { return nu_trues_for_list(self, block); }

- (id)componentsJoinedByString:(id)obj
{
    NSMutableString *str = [[[NSMutableString alloc] init] autorelease];
    BOOL first = YES;
    NSString *sep = [obj description];
    id cursor = self;
    while (cursor && (cursor != Nu__null)) {
        if (!first) {
            [str appendString:sep];
        } else {
            first = NO;
        }
        [str appendString:[[cursor car] description]];
        cursor = [cursor cdr];
    }
    return str;
}

- (id)join:(id)obj
{
    return [self componentsJoinedByString:obj];
}

- (NSUInteger) length
{
    int count = 0;
    id cursor = self;
    while (cursor && (cursor != Nu__null)) {
        cursor = [cursor cdr];
        count++;
    }
    return count;
}

- (NSMutableArray *) array
{
    NSMutableArray *a = [NSMutableArray array];
    id cursor = self;
    while (cursor && cursor != Nu__null) {
        [a addObject:[cursor car]];
        cursor = [cursor cdr];
    }
    return a;
}

- (NSUInteger) count
{
    return [self length];
}

- (id)sort
{
    return [[[self array] sortedArrayUsingSelector:@selector(compare:)] list];
}

- (id)sort:(id)block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        return [[[self array] sortedArrayUsingBlock:block] list];
    }
    return [self sort];
}

- (id)insert:(id)elt
{
    id obj = [[[NuCell alloc] init] autorelease];
    [obj setCar:[self car]];
    [obj setCdr:[self cdr]];
    [self setCar:elt];
    [self setCdr:obj];
    return self;
}

- (id) comments {return nil;}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:car];
    [coder encodeObject:cdr];
}

- (id) initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        car = [[coder decodeObject] retain];
        cdr = [[coder decodeObject] retain];
    }
    return self;
}

- (void) setFile:(NSString *) f line:(int) l
{
    [file release];
    file = [f retain];
    line = l;
}

- (NSString *) file {return file;}
- (int) line {return line;}
@end

@interface NuCellWithComments ()
{
    id comments;
}
@end

@implementation NuCellWithComments

- (void) dealloc
{
    [comments release];
    [super dealloc];
}

- (id) comments {return comments;}

- (void) setComments:(id) c
{
    [c retain];
    [comments release];
    comments = c;
}

@end



@implementation NSArray(Nu)

- (id)valueForKey:(NSString *)key
{
    return [super valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    return [super setValue:value forKey:key];
}

- (void)swizzleAddObject:(id)anObject
{
    [self swizzleAddObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

- (void)swizzleInsertObject:(id)anObject atIndex:(int)index
{
    [self swizzleInsertObject:((anObject == nil) ? (id)[NSNull null] : anObject) atIndex:index];
}

- (void)swizzleReplaceObjectAtIndex:(int)index withObject:(id)anObject
{
    [self swizzleReplaceObjectAtIndex:index withObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

- (NSString *)stringValue
{
    return [self description];
}

/*- (id)valueForUndefinedKey:(NSString *)key
{
    const char *cstring = [key cStringUsingEncoding:NSUTF8StringEncoding];
    char *endptr;
    long lvalue = strtol(cstring, &endptr, 0);
    if (*endptr != 0)
        return nil;
    
    if (lvalue < 0) {
        // if the index is negative, index from the end of the array
        lvalue += [self count];
    }
    if ((lvalue < [self count]) && (lvalue >= 0)) {
        return [self objectAtIndex:lvalue];
    }
    return Nu__null;
}*/

- (CGPoint)pointValue
{
    if ([self count] != 2)
        return CGPointMake(0.0, 0.0);
    return CGPointMake([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue]);
}

- (NSRange)rangeValue
{
    NSRange r;
    if ([self count] != 2) {
        r.length = 0;
        r.location = 0;
        return r;
    }
    r.length = [[self objectAtIndex:0] unsignedIntegerValue];
    r.location = [[self objectAtIndex:1] unsignedIntegerValue];
    return r;
}

- (CGRect)rectValue
{
    if ([self count] != 4)
        return CGRectMake(0.0, 0.0, 0.0, 0.0);
    return CGRectMake([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue], [[self objectAtIndex:2] floatValue], [[self objectAtIndex:3] floatValue]);
}

- (CGSize)sizeValue
{
    if ([self count] != 2)
        return CGSizeMake(0.0, 0.0);
    return CGSizeMake([[self objectAtIndex:0] floatValue], [[self objectAtIndex:1] floatValue]);
}

- (id)array { return self; }

id arridx(NSArray *arr, int index)
{
    return [arr objectAtIndex:index];
}

id arrip(NSArray *arr, NSIndexPath *ip)
{
    return [[arr objectAtIndex:ip.section] objectAtIndex:ip.row];
}


+ (NSArray *) arrayWithList:(id) list
{
    NSMutableArray *a = [NSMutableArray array];
    id cursor = list;
    while (cursor && cursor != Nu__null) {
        [a addObject:[cursor car]];
        cursor = [cursor cdr];
    }
    return a;
}

// When an unknown message is received by an array, treat it as a call to objectAtIndex:
- (id) handleUnknownMessage:(NuCell *) method withContext:(NSMutableDictionary *) context
{
    if (nu_valueIsNull(method)) {
        return self;
    }
    
    id m = [[method car] evalWithContext:context];
    if ([m isKindOfClass:[NSNumber class]]) {
        int mm = [m intValue];
        if (mm < 0) {
            // if the index is negative, index from the end of the array
            mm += [self count];
        }
        if ((mm < [self count]) && (mm >= 0)) {
            return [self objectAtIndex:mm];
        }
        else {
            return Nu__null;
        }
    }

    return Nu__null;
}

// This default sort method sorts an array using its elements' compare: method.
- (NSArray *) sort
{
    return [self sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)sort:(id)block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        return [self sortedArrayUsingBlock:block];
    }
    return [self sort];
}

// Convert an array into a list.
- (NuCell *) list
{
    NSUInteger count = [self count];
    if (count == 0)
        return nil;
    NuCell *result = [[[NuCell alloc] init] autorelease];
    NuCell *cursor = result;
    [result setCar:[self objectAtIndex:0]];
    for (int i = 1; i < count; i++) {
        [cursor setCdr:[[[NuCell alloc] init] autorelease]];
        cursor = [cursor cdr];
        [cursor setCar:[self objectAtIndex:i]];
    }
    return result;
}

static NSComparisonResult sortedArrayUsingBlockHelper(id a, id b, void *context)
{
    id args = [[NuCell alloc] init];
    [args setCdr:[[[NuCell alloc] init] autorelease]];
    [args setCar:a];
    [[args cdr] setCar:b];
    
    // cast context as a block
    NuBlock *block = (NuBlock *)context;
    id result = [block evalWithArguments:args context:nil];
    
    [args release];
    return [result intValue];
}

- (NSArray *) sortedArrayUsingBlock:(NuBlock *) block
{
    return [self sortedArrayUsingFunction:sortedArrayUsingBlockHelper context:block];
}

- (NSUInteger)length
{
    return [self count];
}

- (NSUInteger) depth
{
    return [self count];
}

- (id) top
{
    return [self lastObject];
}

- (void) dump
{
    for (NSInteger i = [self count]-1; i >= 0; i--) {
        NSLog(@"stack: %@", [self objectAtIndex:i]);
    }
}

- (id)join:(id)obj
{
    return [self componentsJoinedByString:obj];
}

- (id)map:(id)block { return nu_map(self, block, [NSMutableArray class]); }
- (id)mapPairs:(id)block { return nu_map_pairs(self, block, [NSMutableArray class]); }
- (id)mapWithIndex:(id)block { return nu_map_with_index(self, block, [NSMutableArray class]); }

- (id)any:(id)block { return nu_any(self, block); }
- (id)match:(id)block { return nu_match(self, block); }
- (id)keep:(id)block { return nu_keep(self, block, [NSMutableArray class]); }
- (id)remove:(id)block { return nu_remove(self, block, [NSMutableArray class]); }
- (id)all:(id)block { return nu_all(self, block); }
- (id)some:(id)block { return nu_some(self, block); }
- (id)position:(id)block { return nu_position(self, block); }
- (id)trues:(id)block { return nu_trues(self, block, [NSMutableArray class]); }

@end

@implementation NSMutableArray(Nu)

- (void) addObjectsFromList:(id)list
{
    [self addObjectsFromArray:[NSArray arrayWithList:list]];
}

- (void) addPossiblyNullObject:(id)anObject
{
    [self addObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

- (void) insertPossiblyNullObject:(id)anObject atIndex:(int)index
{
    [self insertObject:((anObject == nil) ? (id)[NSNull null] : anObject) atIndex:index];
}

- (void) replaceObjectAtIndex:(int)index withPossiblyNullObject:(id)anObject
{
    [self replaceObjectAtIndex:index withObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

- (void) push:(id) object
{
    [self addObject:object];
}

- (id) pop
{
    if ([self count] > 0) {
        id object = [[self lastObject] retain];
        [self removeLastObject];
		[object autorelease];
        return object;
    }
    else {
        return nil;
    }
}

@end

@implementation NSSet(Nu)

- (id)valueForKey:(NSString *)key
{
    return [super valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    return [super setValue:value forKey:key];
}

- (void)swizzleAddObject:(id)anObject
{
    [self swizzleAddObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}


- (NSString *)stringValue
{
    return [self description];
}

+ (NSSet *) setWithList:(id) list
{
    NSMutableSet *s = [NSMutableSet set];
    id cursor = list;
    while (cursor && cursor != Nu__null) {
        [s addObject:[cursor car]];
        cursor = [cursor cdr];
    }
    return s;
}

// Convert a set into a list.
- (NuCell *) list
{
    NSEnumerator *setEnumerator = [self objectEnumerator];
    NSObject *anObject = [setEnumerator nextObject];
    
    if(!anObject)
        return nil;
    
    NuCell *result = [[[NuCell alloc] init] autorelease];
    NuCell *cursor = result;
    [cursor setCar:anObject];
    
    while ((anObject = [setEnumerator nextObject])) {
        [cursor setCdr:[[[NuCell alloc] init] autorelease]];
        cursor = [cursor cdr];
        [cursor setCar:anObject];
    }
    return result;
}

- (NSUInteger)length
{
    return [self count];
}

- (id)array { return [self allObjects]; }

- (id)map:(id)block { return nu_map(self, block, [NSMutableSet class]); }
- (id)mapPairs:(id)block { return nu_map_pairs(self, block, [NSMutableSet class]); }
- (id)any:(id)block { return nu_any(self, block); }
- (id)match:(id)block { return nu_match(self, block); }
- (id)keep:(id)block { return nu_keep(self, block, [NSMutableSet class]); }
- (id)remove:(id)block { return nu_remove(self, block, [NSMutableSet class]); }
- (id)all:(id)block { return nu_all(self, block); }
- (id)some:(id)block { return nu_some(self, block); }
- (id)trues:(id)block { return nu_trues(self, block, [NSMutableSet class]); }

@end

@implementation NSMutableSet(Nu)

- (void) addPossiblyNullObject:(id)anObject
{
    [self addObject:((anObject == nil) ? (id)[NSNull null] : anObject)];
}

@end

@implementation NSDictionary(Nu)

- (NSArray *)keys { return self.allKeys; }
- (NSArray *)vals { return self.allValues; }

- (BOOL)writeToFile:(NSString *)path { return [self writeToFile:path atomically:YES]; }

- (void)swizzleSetObject:(id)anObject forKey:(id)aKey
{
    [self swizzleSetObject:((anObject == nil) ? (id)[NSNull null] : anObject) forKey:aKey];
}

- (NSString *)stringValue
{
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    [arr addObject:@"{\n"];
    for (id key in self) {
        id val = [self objectForKey:key];
        if (nu_objectIsKindOfClass(val, [NSDictionary class])) {
            [arr addObject:[NSString stringWithFormat:@"\t%@ = %@,\n", [key stringValue], [val description]]];
        } else {
            [arr addObject:[NSString stringWithFormat:@"\t%@ = %@,\n", [key stringValue], [val stringValue]]];
        }
    }
    [arr addObject:@"}\n"];
    return [arr componentsJoinedByString:@""];
}

- (NSData *)jsonEncode
{
    return self.JSONData;
}

- (id)superDescription { return [super description]; }

- (id)array
{
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    NSArray *keys = [self allKeys];
    for (id elt in keys) {
        [arr addObject:[NuPair pair:elt and:[self objectForKey:elt]]];
    }
    return arr;
}

+ (NSDictionary *)dictionaryWithList:(id)list
{
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    id cursor = list;
    while (cursor && (cursor != Nu__null) && ([cursor cdr]) && ([cursor cdr] != Nu__null)) {
        id key = [cursor car];
        if ([key isKindOfClass:[NuSymbol class]] && [key isLabel]) {
            key = [key labelName];
        }
        id value = [[cursor cdr] car];
        if (!value || [value isEqual:[NSNull null]]) {
            [d removeObjectForKey:key];
        } else {
            [d setValue:value forKey:key];
        }
        cursor = [[cursor cdr] cdr];
    }
    return d;
}

- (id) objectForKey:(id)key withDefault:(id)defaultValue
{
    id value = [self objectForKey:key];
    return value ? value : defaultValue;
}

- (id)handleUnknownMessage:(id)message withContext:(NSMutableDictionary *)context
{
    return Nu__null;
}

// Iterate over the key-object pairs in a dictionary. Pass it a block with two arguments: (key object).
- (id) each:(id) block
{
    id lst = nil, cursor = nil, result;
    id args = [[NuCell alloc] init];
    [args setCdr:[[[NuCell alloc] init] autorelease]];
    NSEnumerator *keyEnumerator = [[self allKeys] objectEnumerator];
    id key;
    while ((key = [keyEnumerator nextObject])) {
        @try
        {
            [args setCar:key];
            [[args cdr] setCar:[self objectForKey:key]];
            result = [block evalWithArguments:args context:Nu__null];
            cursor = nucons1(cursor, result);
            if (!lst)
                lst = cursor;
        }
        @catch (NuBreakException *exception) {
            break;
        }
        @catch (NuContinueException *exception) {
            // do nothing, just continue with the next loop iteration
        }
        @catch (id exception) {
            @throw(exception);
        }
    }
    [args release];
    return lst;
}

- (NSUInteger)length
{
    return [self count];
}


@end

@implementation NSMutableDictionary(Nu)

- (id)valueForIvar:(NSString *)name
{
    return [self valueForKey:name];
}

- (void)setValue:(id)value forIvar:(NSString *)name
{
    [self setValue:value forKey:name];
}

- (NSString *)stringValue
{
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    [arr addObject:@"{\n"];
    for (id key in self) {
        id val = [self objectForKey:key];
        if (nu_objectIsKindOfClass(val, [NSDictionary class])) {
            [arr addObject:[NSString stringWithFormat:@"\t%@ = %@,\n", [key stringValue], [val description]]];
        } else {
            [arr addObject:[NSString stringWithFormat:@"\t%@ = %@,\n", [key stringValue], [val stringValue]]];
        }
    }
    [arr addObject:@"}\n"];
    return [arr componentsJoinedByString:@""];
}
- (id)consumeKey:(NSString *)key
{
    id val = [self valueForKey:key];
    if (val) {
        [val retain];
        [self removeObjectForKey:key];
        [val autorelease];
    }
    return val;
}

- (id) lookupObjectForKey:(id)key
{
    id object = [self objectForKey:key];
    if (object) return object;
    
    if (nu_objectIsKindOfClass(key, [NuSymbol class])) {
        object = [self valueForKey:[key stringValue]];
        if (object)
            return object;
    }

    id context = [self valueForKey:@"_object_context"];
    if (context) {
        if (nu_objectIsKindOfClass(key, [NuSymbol class])) {
            @try {
            object = [context valueForKey:[key stringValue]];
            if (object)
                return object;
            } @catch (id e) {
            }
        } else if (nu_objectIsKindOfClass(key, [NSString class])) {
            @try {
            object = [context valueForKey:key];
            if (object)
                return object;
            } @catch (id e) {
            }
        }
    }
    id parent = [self objectForKey:PARENT_KEY];
    if (!parent) return nil;
    return [parent lookupObjectForKey:key];
}

- (void) setPossiblyNullObject:(id) anObject forKey:(id) aKey
{
    [self setObject:((anObject == nil) ? (id)[NSNull null] : anObject) forKey:aKey];
}


@end

@interface NuStringEnumerator : NSEnumerator
{
    NSString *string;
    int index;
}
@end

@implementation NuStringEnumerator

+ (NuStringEnumerator *) enumeratorWithString:(NSString *) string
{
    return [[[self alloc] initWithString:string] autorelease];
}

- (id) initWithString:(NSString *) s
{
    self = [super init];
    string = [s retain];
    index = 0;
    return self;
}

- (id) nextObject {
    if (index < [string length]) {
        return [NSNumber numberWithInt:[string characterAtIndex:index++]];
    } else {
        return nil;
    }
}

- (void) dealloc {
    [string release];
    [super dealloc];
}

@end

@implementation NSURL(Nu)
- (BOOL)removeFile
{
    if (self.isFileURL) {
        NSFileManager *fm = [NSFileManager defaultManager];
        return [fm removeItemAtURL:self error:nil];
    }
    return NO;
}
@end

@implementation NSString(Nu)

- (NSString *)stringFromFile
{
    return [NSString stringWithContentsOfFile:self encoding:NSUTF8StringEncoding error:nil];
}

- (NSArray *)directoriesInDirectory
{
    if (![self isDirectory]) {
        return nil;
    }
    NSArray *contents = [self directoryContents];
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    for (NSString *elt in contents) {
        NSString *path = [self stringByAppendingPathComponent:elt];
        if ([path isDirectory]) {
            [arr addObject:elt];
        }
    }
    return arr;
}

- (NSArray *)directoryContents
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm contentsOfDirectoryAtPath:self error:nil];
}

- (BOOL)makeDirectory
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm createDirectoryAtPath:self withIntermediateDirectories:YES attributes:nil error:nil];
}

- (BOOL)removeFile
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm removeItemAtPath:self error:nil];
}

- (BOOL)copyToFile:(NSString *)dst
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm copyItemAtPath:self toPath:dst error:nil];
}

- (BOOL)moveToFile:(NSString *)dst
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm moveItemAtPath:self toPath:dst error:nil];
}

- (BOOL)fileExists
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:self];
}

- (BOOL)isDirectory
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL val = NO;
    if ([fm fileExistsAtPath:self isDirectory:&val]) {
        return val;
    }
    return NO;
}

- (NSDictionary *)fileAttrs
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm attributesOfItemAtPath:self error:nil];
}

- (BOOL)appendToFile:(NSString *)path
{
    FILE *fp = fopen([path UTF8String], "a");
    if (!fp) {
        return NO;
    }
    fprintf(fp, "%s\n", [[self urlEncode] UTF8String]);
    fclose(fp);
    return YES;
}

- (id)parseEval
{
    if (![self length])
        return nil;
    NuParser *parser = [Nu sharedParser];
    id result = nil;
    @try {
        [parser setFilename:@"user"];
        id progn = [[parser parse:self] retain];
        NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
        result = [progn evalWithContext:context];
        [context release];
        [progn release];
    }
    @catch (NuException* nuException) {
        prn([NSString stringWithFormat:@"%s", [[nuException dump] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    @catch (id exception) {
        prn([NSString stringWithFormat:@"%s: %s",
                   [[exception name] cStringUsingEncoding:NSUTF8StringEncoding],
                   [[exception reason] cStringUsingEncoding:NSUTF8StringEncoding]]);
    }
    [parser reset];
    return result;
}

- (NSString *) stringValue
{
    return self;
}

- (NSString *) escapedStringRepresentation
{
    NSMutableString *result = [NSMutableString stringWithString:@"\""];
    NSUInteger length = [self length];
    for (int i = 0; i < length; i++) {
        unichar c = [self characterAtIndex:i];
        if (c < 32) {
            switch (c) {
                case 0x07: [result appendString:@"\\a"]; break;
                case 0x08: [result appendString:@"\\b"]; break;
                case 0x09: [result appendString:@"\\t"]; break;
                case 0x0a: [result appendString:@"\\n"]; break;
                case 0x0c: [result appendString:@"\\f"]; break;
                case 0x0d: [result appendString:@"\\r"]; break;
                case 0x1b: [result appendString:@"\\e"]; break;
                default:
                    [result appendFormat:@"\\x%02x", c];
            }
        }
        else if (c == '"') {
            [result appendString:@"\\\""];
        }
        else if (c == '\\') {
            [result appendString:@"\\\\"];
        }
        else if (c < 127) {
            [result appendCharacter:c];
        }
        else if (c < 256) {
            [result appendFormat:@"\\x%02x", c];
        }
        else {
            [result appendFormat:@"\\u%04x", c];
        }
    }
    [result appendString:@"\""];
    return result;
}

- (id) evalWithContext:(NSMutableDictionary *) context
{
    NSMutableString *result;
    NSArray *components = [self componentsSeparatedByString:@"#{"];
    if ([components count] == 1) {
        result = [NSMutableString stringWithString:self];
    }
    else {
        id parser = [Nu sharedParser];
        result = [NSMutableString stringWithString:[components objectAtIndex:0]];
        int i;
        for (i = 1; i < [components count]; i++) {
            NSArray *parts = [[components objectAtIndex:i] componentsSeparatedByString:@"}"];
            NSString *expression = [parts objectAtIndex:0];
            // evaluate each expression
            if (expression) {
                id body;
                @synchronized(parser) {
                    body = [parser parse:expression];
                }
                id value = [body evalWithContext:context];
                if (value) {
                    NSString *stringValue = [value stringValue];
                    [result appendString:stringValue];
                }
            }
            [result appendString:[parts objectAtIndex:1]];
            int j = 2;
            while (j < [parts count]) {
                [result appendString:@"}"];
                [result appendString:[parts objectAtIndex:j]];
                j++;
            }
        }
    }
    return result;
}

+ (id) carriageReturn
{
    return [self stringWithCString:"\n" encoding:NSUTF8StringEncoding];
}


+ (NSString *) stringWithData:(NSData *) data encoding:(int) encoding
{
    return [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
}


// If the last character is a newline, delete it.
- (NSString *) chomp
{
    NSInteger lastIndex = [self length] - 1;
    if (lastIndex >= 0) {
        if ([self characterAtIndex:lastIndex] == 10) {
            return [self substringWithRange:NSMakeRange(0, lastIndex)];
        }
        else {
            return self;
        }
    }
    else {
        return self;
    }
}

+ (NSString *) stringWithCharacter:(unichar) c
{
    return [self stringWithFormat:@"%C", c];
}

// Convert a string into a symbol.
- (id) symbolValue
{
    return nusym(self);
}

// Split a string into lines.
- (NSArray *) lines
{
    NSArray *a = [self componentsSeparatedByString:@"\n"];
    if ([[a lastObject] isEqualToString:@""]) {
        return [a subarrayWithRange:NSMakeRange(0, [a count]-1)];
    }
    else {
        return a;
    }
}

- (NSArray *)split:(NSString *)sep
{
    return [self componentsSeparatedByString:sep];
}

// Replace a substring with another.
- (NSString *) replaceString:(NSString *) target withString:(NSString *) replacement
{
    NSMutableString *s = [NSMutableString stringWithString:self];
    [s replaceOccurrencesOfString:target withString:replacement options:0 range:NSMakeRange(0, [self length])];
    return s;
}

- (id) objectEnumerator
{
    return [NuStringEnumerator enumeratorWithString:self];
}

- (id) each:(id) block
{
    id args = [[NuCell alloc] init];
    NSEnumerator *characterEnumerator = [self objectEnumerator];
    id character;
    while ((character = [characterEnumerator nextObject])) {
        @try
        {
            [args setCar:character];
            [block evalWithArguments:args context:Nu__null];
        }
        @catch (NuBreakException *exception) {
            break;
        }
        @catch (NuContinueException *exception) {
            // do nothing, just continue with the next loop iteration
        }
        @catch (id exception) {
            @throw(exception);
        }
    }
    [args release];
    return self;
}

NSString *evhttp_objc_string(char *buf)
{
    if (!buf)
        return nil;
    NSString *str = [NSString stringWithUTF8String:buf];
    void
    event_mm_free_(void *ptr);
    event_mm_free_(buf);
    return str;
}

- (NSString *)htmlEncode
{
    return evhttp_objc_string(evhttp_htmlescape([self UTF8String]));
}

- (NSString *)urlEncode
{
    return evhttp_objc_string(evhttp_uriencode([self UTF8String], -1, 1));
}

- (NSString *)urlDecode
{
    return evhttp_objc_string(evhttp_uridecode([self UTF8String], 1, NULL));
}

- (NSString *)pathEncode
{
    NSString *str = (NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                               NULL,
                                                               (CFStringRef)self,
                                                               NULL,
                                                               (CFStringRef)@"/%",
                                                               kCFStringEncodingUTF8 );
    return [str autorelease];
}

- (NSMutableDictionary *)queryStringDecode
{
    return [[self dataValue] queryStringDecode];
}

- (NSData *)dataValue
{
    return [NSData dataWithBytes:[self UTF8String] length:strlen([self UTF8String])];
}

- (id)jsonDecode
{
    return self.mutableObjectFromJSONString;
}

@end

@implementation NSMutableString(Nu)
- (void) appendCharacter:(unichar) c
{
    [self appendFormat:@"%C", c];
}

@end

@implementation NSData(Nu)

- (BOOL)writeToFile:(NSString *)path { return [self writeToFile:path atomically:YES]; }

- (const unsigned char) byteAtIndex:(int) i
{
	const unsigned char buffer[2];
	[self getBytes:(void *)&buffer range:NSMakeRange(i,1)];
	return buffer[0];
}



// Helper. Included because it's so useful.
- (id) propertyListValue {
    return [NSPropertyListSerialization propertyListWithData:self
                                                     options:NSPropertyListImmutable
                                                      format:nil
                                                       error:nil];
}

- (id)stringValue
{
    return [[[NSString alloc] initWithBytes:[self bytes] length:[self length] encoding:NSUTF8StringEncoding] autorelease];
}

- (id)jsonDecode
{
    return self.mutableObjectFromJSONData;
}

- (NSMutableDictionary *)queryStringDecode
{
    evhtp_kvs_t *query = evhtp_parse_query(self.bytes, self.length);
    if (!query)
        return nil;
    
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    evhtp_kv_t * kv;
    for (kv = TAILQ_FIRST(query); kv != NULL; kv = TAILQ_NEXT(kv, next)) {
        NSLog(@"< (query) %s=%s", kv->key, kv->val);
        [dict setValue:[[NSString stringWithUTF8String:kv->val] urlDecode] forKey:[[NSString stringWithUTF8String:kv->key] urlDecode]];
    }
    
    evhtp_query_free(query);
    
    return dict;
}

@end

@implementation NSNumber(Nu)

- (id)arrayToIncluding:(int)end
{
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    for (int i=[self intValue]; i<=end; i++) {
        [arr addObject:nuint(i)];
    }
    return arr;
}
- (id)arrayTo:(int)end { return [self arrayToIncluding:end]; }
- (id)arrayToExcluding:(int)end { return [self arrayToIncluding:end-1]; }

- (id)listToIncluding:(int)end
{
    int start = [self intValue];
    id head = nil, tail = nil;
    for(int i=start; i<=end; i++) {
        tail = nucons1(tail, nuint(i));
        if (!head)
            head = tail;
    }
    return head;
}
- (id)listTo:(int)end { return [self listToIncluding:end]; }
- (id)listToExcluding:(int)end { return [self listToIncluding:end-1]; }

- (id) times:(id) block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        int x = [self intValue];
        int i;
        for (i = 0; i < x; i++) {
            @try
            {
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                [args setCar:[NSNumber numberWithInt:i]];
                [block evalWithArguments:args context:Nu__null];
                [pool release];
            }
            @catch (NuBreakException *exception) {
                break;
            }
            @catch (NuContinueException *exception) {
                // do nothing, just continue with the next loop iteration
            }
            @catch (id exception) {
                @throw(exception);
            }
        }
        [args release];
    }
    return self;
}

- (id) downTo:(id) number do:(id) block
{
    int startValue = [self intValue];
    int finalValue = [number intValue];
    if (startValue < finalValue) {
        return self;
    }
    else {
        id args = [[NuCell alloc] init];
        if (nu_objectIsKindOfClass(block, [NuBlock class])) {
            int i;
            for (i = startValue; i >= finalValue; i--) {
                @try
                {
                    [args setCar:[NSNumber numberWithInt:i]];
                    [block evalWithArguments:args context:Nu__null];
                }
                @catch (NuBreakException *exception) {
                    break;
                }
                @catch (NuContinueException *exception) {
                    // do nothing, just continue with the next loop iteration
                }
                @catch (id exception) {
                    @throw(exception);
                }
            }
        }
        [args release];
    }
    return self;
}

- (id)upToExcluding:(id) number block:(id) block
{
    id result = nil;
    int startValue = [self intValue];
    int finalValue = [number intValue];
    id args = [[NuCell alloc] init];
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        int i;
        for (i = startValue; i < finalValue; i++) {
            @try
            {
                [args setCar:[NSNumber numberWithInt:i]];
                result = [block evalWithArguments:args context:Nu__null];
            }
            @catch (NuBreakException *exception) {
                break;
            }
            @catch (NuContinueException *exception) {
                // do nothing, just continue with the next loop iteration
            }
            @catch (id exception) {
                @throw(exception);
            }
        }
    }
    [args release];
    return result;
}

- (id)upToIncluding:(id)number block:(id)block
{
    return [self upToExclusive:[NSNumber numberWithInt:[number intValue]+1] block:block];
}

- (id)upTo:(id)number block:(id)block
{
    return [self upToExclusive:number block:block];
}

- (NSString *) hexValue
{
    int x = [self intValue];
    return [NSString stringWithFormat:@"0x%x", x];
}

@end






@implementation NuPair

+ (id)pair:(id)a and:(id)b
{
    return [[[self alloc] initWith:a and:b] autorelease];
}

- (void)dealloc
{
    self.a = nil;
    self.b = nil;
    [super dealloc];
}

- (id)initWith:(id)a and:(id)b
{
    self = [super init];
    if (self) {
        self.a = a;
        self.b = b;
    }
    return self;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ : %@", [self.a description], [self.b description]];
}

- (NSString *)stringValue { return [self description]; }
@end


@implementation UIView(Nu)

- (id)handleUnknownMessage:(id)message withContext:(NSMutableDictionary *)context
{
    if (nu_valueIsNull(message))
        return self.subviews;
    if (nu_objectIsKindOfClass([message car], [NSNumber class])) {
        int mm = [[message car] intValue];
        if (mm < 0) {
            // if the index is negative, index from the end of the array
            mm += [self.subviews length];
        }
        return [self.subviews objectAtIndex:mm];
    }
    return Nu__null;
}

- (void)dealloc
{
//    NSLog(@"UIView dealloc %@", self);
    id block = [self valueForIvar:@"deallocBlock"];
    if (block) {
        execute_block_safely(^(void) { return [block evalWithArguments:nil]; });
    }
    [super dealloc];
}

+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"frame"];
    CGRect frame = (obj) ? [obj rectValue] : CGRectZero;
    obj = [[[self alloc] initWithFrame:frame] autorelease];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;    
}

- (void)didMoveToSuperview
{
    id block = [self valueForIvar:@"didMoveToSuperview"];
    if (block) {
        execute_block_safely(^(void) { return [block evalWithArguments:nil]; });
    }
}

- (void)swizzleLayoutSubviews
{
    id block = [self valueForIvar:@"layoutSubviews"];
    if (block) {
        execute_block_safely(^(void) { return [block evalWithArguments:nil]; });
        return;
    }
    [self swizzleLayoutSubviews];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    id block = [self valueForIvar:@"touchesBegan:withEvent:"];
    if (!nu_valueIsNull(block)) {
        execute_block_safely(^(void) { return [block evalWithArguments:nulist(touches, event, nil)]; });
        return;
    }
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    id block = [self valueForIvar:@"touchesCancelled:withEvent:"];
    if (!nu_valueIsNull(block)) {
        execute_block_safely(^(void) { return [block evalWithArguments:nulist(touches, event, nil)]; });
        return;
    }
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    id block = [self valueForIvar:@"touchesEnded:withEvent:"];
    if (!nu_valueIsNull(block)) {
        execute_block_safely(^(void) { return [block evalWithArguments:nulist(touches, event, nil)]; });
        return;
    }
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    id block = [self valueForIvar:@"touchesMoved:withEvent:"];
    if (!nu_valueIsNull(block)) {
        execute_block_safely(^(void) { return [block evalWithArguments:nulist(touches, event, nil)]; });
        return;
    }
    [super touchesMoved:touches withEvent:event];
}

- (CGFloat)x { return self.frame.origin.x; }
- (CGFloat)y { return self.frame.origin.y; }
- (CGFloat)w { return self.frame.size.width; }
- (CGFloat)h { return self.frame.size.height; }
- (void)setX:(CGFloat)x
{
    CGRect r = self.frame;
    r.origin.x = x;
    self.frame = r;
}
- (void)setY:(CGFloat)y
{
    CGRect r = self.frame;
    r.origin.y = y;
    self.frame = r;
}
- (void)setW:(CGFloat)w
{
    CGRect r = self.frame;
    r.size.width = w;
    self.frame = r;
}
- (void)setH:(CGFloat)h
{
    CGRect r = self.frame;
    r.size.height = h;
    self.frame = r;
}

@end


@implementation UIViewController(Nu)

- (void)swizzleLoadView
{
    id block = [self valueForIvar:@"loadView"];
    if (block) {
        execute_block_safely(^(void) { return [block evalWithArguments:nil]; });
        return;
    }
    [self swizzleLoadView];
}
- (void)swizzleViewWillAppear:(BOOL)animated
{
    [self swizzleViewWillAppear:animated];
    id block = [self valueForIvar:@"viewWillAppearBlock:"];
    if (block) {
        execute_block_safely(^(void) { return [block evalWithArguments:nulist(nuint(animated), nil)]; });
    }
}
- (void)swizzleViewDidAppear:(BOOL)animated
{
    [self swizzleViewDidAppear:animated];
    id block = [self valueForIvar:@"viewDidAppearBlock:"];
    if (block) {
        execute_block_safely(^(void) { return [block evalWithArguments:nulist(nuint(animated), nil)]; });
    }
}

@end

@implementation UITableView(Nu)
+ (id)objectWithProperties:(NSDictionary *)dict
{
    NSMutableDictionary *prop = [dict mutableCopy];
    id obj = [prop consumeKey:@"frame"];
    CGRect frame = (obj) ? [obj rectValue] : CGRectZero;
    obj = [prop consumeKey:@"style"];
    UITableViewStyle style = (obj) ? [obj intValue] : UITableViewStylePlain;
    obj = [[[self alloc] initWithFrame:frame style:style] autorelease];
    [obj setValuesForKeysWithDictionary:prop];
    return obj;
}

- (id)data
{
    return [self valueForIvar:@"data"];
}

- (void)setData:(id)data
{
    if (nu_objectIsKindOfClass(data, [NSDictionary class])) {
        [self setDataSource:data];
        [self setDelegate:data];
        [self setValue:data forIvar:@"data"];
        [self reloadData];
        NSLog(@"reloaded UITableView %@", data);
    }
}

@end

@implementation UIImage(Nu)

- (CGFloat)w { return self.size.width; }
- (CGFloat)h { return self.size.height; }

@end