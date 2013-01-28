//
//  NuOperators.m
//  Nu
//
//  Created by arthur on 4/11/12.
//
//

#import "Nu.h"
#import "Misc.h"
#import "cocos2d.h"
#include <sys/utsname.h>

@interface Nu_car_operator : NuOperator {}
@end

@implementation Nu_car_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cadr = [cdr car];
    id value = [cadr evalWithContext:context];
    return ([value respondsToSelector:@selector(car)]) ? [value car] : Nu__null;
}

@end

@interface Nu_cdr_operator : NuOperator {}
@end

@implementation Nu_cdr_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cadr = [cdr car];
    id value = [cadr evalWithContext:context];
    return ([value respondsToSelector:@selector(cdr)]) ? [value cdr] : Nu__null;
}

@end

@interface Nu_atom_operator : NuOperator {}
@end

@implementation Nu_atom_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cadr = [cdr car];
    id value = [cadr evalWithContext:context];
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    if ([value atom])
        return Nu__t;
    else
        return Nu__null;
}

@end

@interface Nu_defined_operator : NuOperator {}
@end

@implementation Nu_defined_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    bool is_defined = YES;
    id cadr = [cdr car];
    @try
    {
        [cadr evalWithContext:context];
    }
    @catch (id exception) {
        // is this an undefined symbol exception? if not, throw it
        if ([[exception name] isEqualToString:@"NuUndefinedSymbol"]) {
            is_defined = NO;
        }
        else {
            @throw(exception);
        }
    }
    return (is_defined) ? Nu__t : Nu__null;
}

@end

@interface Nu_eq_operator : NuOperator {}
@end

@implementation Nu_eq_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id cursor = cdr;
    id current = [[cursor car] evalWithContext:context];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        id next = [[cursor car] evalWithContext: context];
        if (![current isEqual:next])
            return Nu__null;
        current = next;
        cursor = [cursor cdr];
    }
    return [symbolTable symbolWithString:@"t"];
}

@end

@interface Nu_neq_operator : NuOperator {}
@end

@implementation Nu_neq_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cadr = [cdr car];
    id caddr = [[cdr cdr] car];
    id value1 = [cadr evalWithContext:context];
    id value2 = [caddr evalWithContext:context];
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    if ((value1 == nil) && (value2 == nil)) {
        return Nu__null;
    }
    else if ([value1 isEqual:value2]) {
        return Nu__null;
    }
    else {
        return [symbolTable symbolWithString:@"t"];
    }
}

@end

@interface Nu_pointereq_operator : NuOperator {}
@end

@implementation Nu_pointereq_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id cursor = cdr;
    id current = [[cursor car] evalWithContext:context];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        id next = [[cursor car] evalWithContext: context];
        if (current != next)
            return Nu__null;
        current = next;
        cursor = [cursor cdr];
    }
    return [symbolTable symbolWithString:@"t"];
}

@end

@interface Nu_cons_operator : NuOperator {}
@end

@implementation Nu_cons_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cadr = [cdr car];
    id cddr = [cdr cdr];
    id value1 = [cadr evalWithContext:context];
    id value2 = [cddr evalWithContext:context];
    id newCell = [[[NuCell alloc] init] autorelease];
    [newCell setCar:value1];
    [newCell setCdr:value2];
    return newCell;
}

@end

@interface Nu_append_operator : NuOperator {}
@end

@implementation Nu_append_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id newList = Nu__null;
    id cursor = nil;
    id list_to_append = cdr;
    while (list_to_append && (list_to_append != Nu__null)) {
        id item_to_append = [[list_to_append car] evalWithContext:context];
        while (item_to_append && (item_to_append != Nu__null)) {
            if (newList == Nu__null) {
                newList = [[[NuCell alloc] init] autorelease];
                cursor = newList;
            }
            else {
                [cursor setCdr: [[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
            }
            id item = [item_to_append car];
            [cursor setCar: item];
            item_to_append = [item_to_append cdr];
        }
        list_to_append = [list_to_append cdr];
    }
    return newList;
}

@end

@interface Nu_if_operator : NuOperator {}
@end

@implementation Nu_if_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    id condition, branch;
    while (cursor && (cursor != Nu__null)) {
        condition = [cursor car];
        cursor = [cursor cdr];
        if (cursor && (cursor != Nu__null)) {
            branch = [cursor car];
            cursor = [cursor cdr];
        } else {
            return [condition evalWithContext:context];
        }
        id test = [condition evalWithContext:context];
        if (nu_valueIsTrue(test)) {
            return [branch evalWithContext:context];
        }
    }
    return Nu__null;
}
@end



@interface Nu_case_operator : NuOperator {}
@end

@implementation Nu_case_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    id target = [[cursor car] evalWithContext:context];
    cursor = [cursor cdr];
    
    id condition, branch;
    while (cursor && (cursor != Nu__null)) {
        condition = [cursor car];
        cursor = [cursor cdr];
        if (cursor && (cursor != Nu__null)) {
            branch = [cursor car];
            cursor = [cursor cdr];
        } else {
            return [condition evalWithContext:context];
        }
        id result = [condition evalWithContext:context];
        if ([result isEqual:target]) {
            return [branch evalWithContext:context];
        }
    }
    return Nu__null;
}

@end

@interface Nu_when_operator : NuOperator {}
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context flipped:(bool)flip;
@end

@implementation Nu_when_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [self callWithArguments:cdr context:context flipped:NO];
}

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context flipped:(bool)flip
{    
    id result = Nu__null;
    id test = [[cdr car] evalWithContext:context];
    
    bool testIsTrue = flip ^ nu_valueIsTrue(test);
    
    id expressions = [cdr cdr];
    while (expressions && (expressions != Nu__null)) {
        id nextExpression = [expressions car];
        if (testIsTrue)
            result = [nextExpression evalWithContext:context];
        expressions = [expressions cdr];
    }
    return result;
}

@end

@interface Nu_unless_operator : Nu_when_operator {}
@end

@implementation Nu_unless_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [super callWithArguments:cdr context:context flipped:YES];
}

@end

@interface Nu_while_operator : NuOperator {}
@end

@implementation Nu_while_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id result = Nu__null;
    id test = [[cdr car] evalWithContext:context];
    while (nu_valueIsTrue(test)) {
        @try
        {
            id expressions = [cdr cdr];
            while (expressions && (expressions != Nu__null)) {
                result = [[expressions car] evalWithContext:context];
                expressions = [expressions cdr];
            }
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
        test = [[cdr car] evalWithContext:context];
    }
    return result;
}

@end

@interface Nu_until_operator : NuOperator {}
@end

@implementation Nu_until_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id result = Nu__null;
    id test = [[cdr car] evalWithContext:context];
    while (!nu_valueIsTrue(test)) {
        @try
        {
            id expressions = [cdr cdr];
            while (expressions && (expressions != Nu__null)) {
                result = [[expressions car] evalWithContext:context];
                expressions = [expressions cdr];
            }
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
        test = [[cdr car] evalWithContext:context];
    }
    return result;
}

@end

@interface Nu_loop_operator : NuOperator {}
@end

@implementation Nu_loop_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id result = Nu__null;
    id controls = [cdr car];                      // this could use some error checking!
    id loopinit = [controls car];
    id looptest = [[controls cdr] car];
    id loopincr = [[[controls cdr] cdr] car];
    // initialize the loop
    [loopinit evalWithContext:context];
    // evaluate the loop condition
    id test = [looptest evalWithContext:context];
    while (nu_valueIsTrue(test)) {
        @try
        {
            id expressions = [cdr cdr];
            while (expressions && (expressions != Nu__null)) {
                result = [[expressions car] evalWithContext:context];
                expressions = [expressions cdr];
            }
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
        // perform the end of loop increment step
        [loopincr evalWithContext:context];
        // evaluate the loop condition
        test = [looptest evalWithContext:context];
    }
    return result;
}

@end

@interface Nu_try_operator : NuOperator {}
@end

@implementation Nu_try_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id catchSymbol = [symbolTable symbolWithString:@"catch"];
    id finallySymbol = [symbolTable symbolWithString:@"finally"];
    id result = Nu__null;
    
    @try
    {
        // evaluate all the expressions that are outside catch and finally blocks
        id expressions = cdr;
        while (expressions && (expressions != Nu__null)) {
            id nextExpression = [expressions car];
            if (nu_objectIsKindOfClass(nextExpression, [NuCell class])) {
                if (([nextExpression car] != catchSymbol) && ([nextExpression car] != finallySymbol)) {
                    result = [nextExpression evalWithContext:context];
                }
            }
            else {
                result = [nextExpression evalWithContext:context];
            }
            expressions = [expressions cdr];
        }
    }
    @catch (id thrownObject) {
        // evaluate all the expressions that are in catch blocks
        id expressions = cdr;
        while (expressions && (expressions != Nu__null)) {
            id nextExpression = [expressions car];
            if (nu_objectIsKindOfClass(nextExpression, [NuCell class])) {
                if (([nextExpression car] == catchSymbol)) {
                    // this is a catch block.
                    // the first expression should be a list with a single symbol
                    // that's a name.  we'll set that name to the thing we caught
                    id nameList = [[nextExpression cdr] car];
                    id name = [nameList car];
                    [context setValue:thrownObject forKey:name];
                    // now we loop over the rest of the expressions and evaluate them one by one
                    id cursor = [[nextExpression cdr] cdr];
                    while (cursor && (cursor != Nu__null)) {
                        result = [[cursor car] evalWithContext:context];
                        cursor = [cursor cdr];
                    }
                }
            }
            expressions = [expressions cdr];
        }
    }
    @finally
    {
        // evaluate all the expressions that are in finally blocks
        id expressions = cdr;
        while (expressions && (expressions != Nu__null)) {
            id nextExpression = [expressions car];
            if (nu_objectIsKindOfClass(nextExpression, [NuCell class])) {
                if (([nextExpression car] == finallySymbol)) {
                    // this is a finally block
                    // loop over the rest of the expressions and evaluate them one by one
                    id cursor = [nextExpression cdr];
                    while (cursor && (cursor != Nu__null)) {
                        result = [[cursor car] evalWithContext:context];
                        cursor = [cursor cdr];
                    }
                }
            }
            expressions = [expressions cdr];
        }
    }
    return result;
}

@end

@interface Nu_throw_operator : NuOperator {}
@end

@implementation Nu_throw_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id exception = [[cdr car] evalWithContext:context];
    @throw exception;
    return exception;
}

@end

@interface Nu_synchronized_operator : NuOperator {}
@end

@implementation Nu_synchronized_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    //  NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    
    id object = [[cdr car] evalWithContext:context];
    id result = Nu__null;
    
    @synchronized(object) {
        // evaluate the rest of the expressions
        id expressions = [cdr cdr];
        while (expressions && (expressions != Nu__null)) {
            id nextExpression = [expressions car];
            result = [nextExpression evalWithContext:context];
            expressions = [expressions cdr];
        }
    }
    return result;
}

@end

@interface Nu_quote_operator : NuOperator {}
@end

@implementation Nu_quote_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cadr = [cdr car];
    return cadr;
}

@end

@interface Nu_quasiquote_eval_operator : NuOperator {}
@end

@implementation Nu_quasiquote_eval_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    // bqcomma is handled by Nu_quasiquote_operator.
    // If we get here, it means someone called bq_comma
    // outside of a backquote
    [NSException raise:@"NuQuasiquoteEvalOutsideQuasiquote"
                format:@"Comma must be inside a backquote"];
    
    // Purely cosmetic...
    return Nu__null;
}

@end

@interface Nu_quasiquote_splice_operator : NuOperator {}
@end

@implementation Nu_quasiquote_splice_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    // bqcomma-at is handled by Nu_quasiquote_operator.
    // If we get here, it means someone called bq_comma
    // outside of a backquote
    [NSException raise:@"NuQuasiquoteSpliceOutsideQuasiquote"
                format:@"Comma-at must be inside a backquote"];
    
    // Purely cosmetic...
    return Nu__null;
}

@end

// Temporary use for debugging quasiquote functions...
#if 0
#define QuasiLog(args...)   NSLog(args)
#else
#define QuasiLog(args...)
#endif

@interface Nu_quasiquote_operator : NuOperator {}
@end

@implementation Nu_quasiquote_operator

- (id) evalQuasiquote:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    
    id quasiquote_eval = [[symbolTable symbolWithString:@"quasiquote-eval"] value];
    id quasiquote_splice = [[symbolTable symbolWithString:@"quasiquote-splice"] value];
    
    QuasiLog(@"bq:Entered. callWithArguments cdr = %@", [cdr stringValue]);
    
    id result = Nu__null;
    id result_cursor = Nu__null;
    id cursor = cdr;
    
    while (cursor && (cursor != Nu__null)) {
        id value;
        QuasiLog(@"quasiquote: [cursor car] == %@", [[cursor car] stringValue]);
        
        if ([[cursor car] atom]) {
            // Treat it as a quoted value
            QuasiLog(@"quasiquote: Quoting cursor car: %@", [[cursor car] stringValue]);
            value = [cursor car];
        }
        else if ([cursor car] == Nu__null) {
            QuasiLog(@"  quasiquote: null-list");
            value = Nu__null;
        }
        else if ([[symbolTable lookup:[[[cursor car] car] stringValue]] value] == quasiquote_eval) {
            QuasiLog(@"quasiquote-eval: Evaling: [[cursor car] cdr]: %@", [[[cursor car] cdr] stringValue]);
            value = [[[cursor car] cdr] evalWithContext:context];
            QuasiLog(@"  quasiquote-eval: Value: %@", [value stringValue]);
        }
        else if ([[symbolTable lookup:[[[cursor car] car] stringValue]] value] == quasiquote_splice) {
            QuasiLog(@"quasiquote-splice: Evaling: [[cursor car] cdr]: %@",
                     [[[cursor car] cdr] stringValue]);
            value = [[[cursor car] cdr] evalWithContext:context];
            QuasiLog(@"  quasiquote-splice: Value: %@", [value stringValue]);
            
            if (value != Nu__null && [value atom]) {
                [NSException raise:@"NuQuasiquoteSpliceNoListError"
                            format:@"An atom was passed to Quasiquote splicer.  Splicing can only splice a list."];
            }
            
            id value_cursor = value;
            
            while (value_cursor && (value_cursor != Nu__null)) {
                id value_item = [value_cursor car];
                
                if (result_cursor == Nu__null) {
                    result_cursor = [[[NuCell alloc] init] autorelease];
                    result = result_cursor;
                }
                else {
                    [result_cursor setCdr: [[[NuCell alloc] init] autorelease]];
                    result_cursor = [result_cursor cdr];
                }
                
                [result_cursor setCar: value_item];
                value_cursor = [value_cursor cdr];
            }
            
            QuasiLog(@"  quasiquote-splice-append: result: %@", [result stringValue]);
            
            cursor = [cursor cdr];
            
            // Don't want to do the normal cursor handling at bottom of the loop
            // in this case as we've already done it in the splicing above...
            continue;
        }
        else {
            QuasiLog(@"quasiquote: recursive callWithArguments: %@", [[cursor car] stringValue]);
            value = [self evalQuasiquote:[cursor car] context:context];
            QuasiLog(@"quasiquote: leaving recursive call with value: %@", [value stringValue]);
        }
        
        if (result == Nu__null) {
            result = [[[NuCell alloc] init] autorelease];
            result_cursor = result;
        }
        else {
            [result_cursor setCdr:[[[NuCell alloc] init] autorelease]];
            result_cursor = [result_cursor cdr];
        }
        
        [result_cursor setCar:value];
        
        QuasiLog(@"quasiquote: result_cursor: %@", [result_cursor stringValue]);
        QuasiLog(@"quasiquote: result:        %@", [result stringValue]);
        
        cursor = [cursor cdr];
    }
    QuasiLog(@"quasiquote: returning result = %@", [result stringValue]);
    return result;
}

#if 0
@implementation Nu_append_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id newList = Nu__null;
    id cursor = nil;
    id list_to_append = cdr;
    while (list_to_append && (list_to_append != Nu__null)) {
        id item_to_append = [[list_to_append car] evalWithContext:context];
        while (item_to_append && (item_to_append != Nu__null)) {
            if (newList == Nu__null) {
                newList = [[[NuCell alloc] init] autorelease];
                cursor = newList;
            }
            else {
                [cursor setCdr: [[[NuCell alloc] init] autorelease]];
                cursor = [cursor cdr];
            }
            id item = [item_to_append car];
            [cursor setCar: item];
            item_to_append = [item_to_append cdr];
        }
        list_to_append = [list_to_append cdr];
    }
    return newList;
}

@end
#endif

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [[self evalQuasiquote:cdr context:context] car];
}

@end

@interface Nu_context_operator : NuOperator {}
@end

@implementation Nu_context_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return context;
}

@end

@interface Nu_local_operator : NuOperator {}
@end

@implementation Nu_local_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    
    NuSymbol *symbol = [cdr car];
    id value = [[cdr cdr] car];
    id result = [value evalWithContext:context];
    
    char c = (char) [[symbol stringValue] characterAtIndex:0];
    if (c == '$') {
        [symbol setValue:result];
    }
    else if (c == '@') {
        NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
        id object = [context lookupObjectForKey:[symbolTable symbolWithString:@"self"]];
        id ivar = [[symbol stringValue] substringFromIndex:1];
        [object setValue:result forIvar:ivar];
    }
    else {
#ifndef CLOSE_ON_VALUES
        NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
        id classSymbol = [symbolTable symbolWithString:@"_class"];
        id searchContext = context;
        while (searchContext) {
            if ([searchContext objectForKey:symbol]) {
                [searchContext setPossiblyNullObject:result forKey:symbol];
                return result;
            }
            else if ([searchContext objectForKey:classSymbol]) {
                break;
            }
            searchContext = [searchContext objectForKey:PARENT_KEY];
        }
#endif
        [context setPossiblyNullObject:result forKey:symbol];
    }
    return result;
}

@end

@interface Nu_global_operator : NuOperator {}
@end

@implementation Nu_global_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    
    NuSymbol *symbol = [cdr car];
    id cursor = [cdr cdr];
    if (cursor && (cursor != Nu__null)) {
        id value = [[cdr cdr] car];
        id result = [value evalWithContext:context];
        [symbol setValue:result];
        return result;
    }
    [symbol setValue:nil];
    return [NSNull null];
}

@end




@implementation Nu_fn_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id args = [cdr car];
    id body = [cdr cdr];
    NuBlock *block = [[[NuBlock alloc] initWithParameters:args body:body context:context] autorelease];
    return block;
}

@end


@interface Nu_label_operator : NuOperator {}
@end

@implementation Nu_label_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id symbol = [cdr car];
    id value = [[cdr cdr] car];
    value = [value evalWithContext:context];
    if (nu_objectIsKindOfClass(value, [NuBlock class])) {
        //NSLog(@"setting context[%@] = %@", symbol, value);
        [((NSMutableDictionary *)[value context]) setPossiblyNullObject:value forKey:symbol];
    }
    return value;
}

@end

@interface Nu_macro_0_operator : NuOperator {}
@end

@implementation Nu_macro_0_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [[[NuMacro_0 alloc] initWithBody:cdr] autorelease];
}

@end

@interface Nu_macro_1_operator : NuOperator {}
@end

@implementation Nu_macro_1_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id args = [cdr car];
    id body = [cdr cdr];
    
    return [[[NuMacro_1 alloc] initWithParameters:args body:body] autorelease];
}

@end

@interface Nu_macrox_operator : NuOperator {}
@end

@implementation Nu_macrox_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id call = [cdr car];
    id name = [call car];
    id margs = [call cdr];
    
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id macro = [name evalWithContext:context];
    
    if (macro == nil) {
        [NSException raise:@"NuMacroxWrongType" format:@"macrox was called on an object which is not a macro"];
    }
    
    id expanded = [macro expand1:margs context:context];
    return expanded;
}

@end

@interface Nu_list_operator : NuOperator {}
@end

@implementation Nu_list_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id result = Nu__null;
    id cursor = cdr;
    id result_cursor = Nu__null;
    while (cursor && (cursor != Nu__null)) {
        if (result == Nu__null) {
            result = [[[NuCell alloc] init] autorelease];
            result_cursor = result;
        }
        else {
            [result_cursor setCdr:[[[NuCell alloc] init] autorelease]];
            result_cursor = [result_cursor cdr];
        }
        id value = [[cursor car] evalWithContext:context];
        [result_cursor setCar:value];
        cursor = [cursor cdr];
    }
    return result;
}

@end

@interface Nu_add_operator : NuOperator {}
@end

@implementation Nu_add_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    if ([context objectForKey:[symbolTable symbolWithString:@"_class"]] && ![context objectForKey:[symbolTable symbolWithString:@"_method"]]) {
        // we are inside a class declaration and outside a method declaration.
        // treat this as a "cmethod" call
        NuClass *classWrapper = [context objectForKey:[symbolTable symbolWithString:@"_class"]];
        [classWrapper registerClass];
        Class classToExtend = [classWrapper wrappedClass];
        return help_add_method_to_class(classToExtend, cdr, context, YES);
    }
    // otherwise, it's an addition
    id firstArgument = [[cdr car] evalWithContext:context];
    if (nu_objectIsKindOfClass(firstArgument, [NSValue class])) {
        double sum = [firstArgument doubleValue];
        id cursor = [cdr cdr];
        while (cursor && (cursor != Nu__null)) {
            sum += [[[cursor car] evalWithContext:context] doubleValue];
            cursor = [cursor cdr];
        }
        return [NSNumber numberWithDouble:sum];
    }
    else {
        NSMutableString *result = [NSMutableString stringWithString:[firstArgument stringValue]];
        id cursor = [cdr cdr];
        while (cursor && (cursor != Nu__null)) {
            id carValue = [[cursor car] evalWithContext:context];
            if (carValue && (carValue != Nu__null)) {
                [result appendString:[carValue stringValue]];
            }
            cursor = [cursor cdr];
        }
        return result;
    }
}

@end

@interface Nu_multiply_operator : NuOperator {}
@end

@implementation Nu_multiply_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    double product = 1;
    id cursor = cdr;
    while (cursor && (cursor != Nu__null)) {
        product *= [[[cursor car] evalWithContext:context] doubleValue];
        cursor = [cursor cdr];
    }
    return [NSNumber numberWithDouble:product];
}

@end

@interface Nu_subtract_operator : NuOperator {}
@end

@implementation Nu_subtract_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    if ([context objectForKey:[symbolTable symbolWithString:@"_class"]] && ![context objectForKey:[symbolTable symbolWithString:@"_method"]]) {
        // we are inside a class declaration and outside a method declaration.
        // treat this as an "imethod" call
        NuClass *classWrapper = [context objectForKey:[symbolTable symbolWithString:@"_class"]];
        [classWrapper registerClass];
        Class classToExtend = [classWrapper wrappedClass];
        return help_add_method_to_class(classToExtend, cdr, context, NO);
    }
    // otherwise, it's a subtraction
    id cursor = cdr;
    double sum = [[[cursor car] evalWithContext:context] doubleValue];
    cursor = [cursor cdr];
    if (!cursor || (cursor == Nu__null)) {
        // if there is just one operand, negate it
        sum = -sum;
    }
    else {
        // otherwise, subtract all the remaining operands from the first one
        while (cursor && (cursor != Nu__null)) {
            sum -= [[[cursor car] evalWithContext:context] doubleValue];
            cursor = [cursor cdr];
        }
    }
    return [NSNumber numberWithDouble:sum];
}

@end

@interface Nu_exponentiation_operator : NuOperator {}
@end

@implementation Nu_exponentiation_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    double result = [[[cursor car] evalWithContext:context] doubleValue];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        result = pow(result, [[[cursor car] evalWithContext:context] doubleValue]);
        cursor = [cursor cdr];
    }
    return [NSNumber numberWithDouble:result];
}

@end

@interface Nu_divide_operator : NuOperator {}
@end

@implementation Nu_divide_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    double product = [[[cursor car] evalWithContext:context] doubleValue];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        product /= [[[cursor car] evalWithContext:context] doubleValue];
        cursor = [cursor cdr];
    }
    return [NSNumber numberWithDouble:product];
}

@end

@interface Nu_modulus_operator : NuOperator {}
@end

@implementation Nu_modulus_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    int product = [[[cursor car] evalWithContext:context] intValue];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        product %= [[[cursor car] evalWithContext:context] intValue];
        cursor = [cursor cdr];
    }
    return [NSNumber numberWithInt:product];
}

@end

@interface Nu_bitwiseand_operator : NuOperator {}
@end

@implementation Nu_bitwiseand_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    long result = [[[cursor car] evalWithContext:context] longValue];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        result &= [[[cursor car] evalWithContext:context] longValue];
        cursor = [cursor cdr];
    }
    return [NSNumber numberWithLong:result];
}

@end

@interface Nu_bitwiseor_operator : NuOperator {}
@end

@implementation Nu_bitwiseor_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    long result = [[[cursor car] evalWithContext:context] longValue];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        result |= [[[cursor car] evalWithContext:context] longValue];
        cursor = [cursor cdr];
    }
    return [NSNumber numberWithLong:result];
}

@end

@interface Nu_greaterthan_operator : NuOperator {}
@end

@implementation Nu_greaterthan_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id cursor = cdr;
    id current = [[cursor car] evalWithContext:context];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        id next = [[cursor car] evalWithContext:context];
        NSComparisonResult result = [current compare:next];
        if (result != NSOrderedDescending)
            return Nu__null;
        current = next;
        cursor = [cursor cdr];
    }
    return [symbolTable symbolWithString:@"t"];
}

@end

@interface Nu_lessthan_operator : NuOperator {}
@end

@implementation Nu_lessthan_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id cursor = cdr;
    id current = [[cursor car] evalWithContext:context];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        id next = [[cursor car] evalWithContext:context];
        NSComparisonResult result = [current compare:next];
        if (result != NSOrderedAscending)
            return Nu__null;
        current = next;
        cursor = [cursor cdr];
    }
    return [symbolTable symbolWithString:@"t"];
}

@end

@interface Nu_gte_operator : NuOperator {}
@end

@implementation Nu_gte_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id cursor = cdr;
    id current = [[cursor car] evalWithContext:context];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        id next = [[cursor car] evalWithContext:context];
        NSComparisonResult result = [current compare:next];
        if (result == NSOrderedAscending)
            return Nu__null;
        current = next;
        cursor = [cursor cdr];
    }
    return [symbolTable symbolWithString:@"t"];
}

@end

@interface Nu_lte_operator : NuOperator {}
@end

@implementation Nu_lte_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id cursor = cdr;
    id current = [[cursor car] evalWithContext:context];
    cursor = [cursor cdr];
    while (cursor && (cursor != Nu__null)) {
        id next = [[cursor car] evalWithContext:context];
        NSComparisonResult result = [current compare:next];
        if (result == NSOrderedDescending)
            return Nu__null;
        current = next;
        cursor = [cursor cdr];
    }
    return [symbolTable symbolWithString:@"t"];
}

@end

@interface Nu_leftshift_operator : NuOperator {}
@end

@implementation Nu_leftshift_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    long result = [[[cdr car] evalWithContext:context] longValue];
    result = result << [[[[cdr cdr] car] evalWithContext:context] longValue];
    return [NSNumber numberWithLong:result];
}

@end

@interface Nu_rightshift_operator : NuOperator {}
@end

@implementation Nu_rightshift_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    long result = [[[cdr car] evalWithContext:context] longValue];
    result = result >> [[[[cdr cdr] car] evalWithContext:context] longValue];
    return [NSNumber numberWithLong:result];
}

@end

@interface Nu_and_operator : NuOperator {}
@end

@implementation Nu_and_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    id value = Nu__null;
    while (cursor && (cursor != Nu__null)) {
        value = [[cursor car] evalWithContext:context];
        if (!nu_valueIsTrue(value))
            return Nu__null;
        cursor = [cursor cdr];
    }
    return value;
}

@end

@interface Nu_or_operator : NuOperator {}
@end

@implementation Nu_or_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id cursor = cdr;
    while (cursor && (cursor != Nu__null)) {
        id value = [[cursor car] evalWithContext:context];
        if (nu_valueIsTrue(value))
            return value;
        cursor = [cursor cdr];
    }
    return Nu__null;
}

@end

@interface Nu_not_operator : NuOperator {}
@end

@implementation Nu_not_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id cursor = cdr;
    if (cursor && (cursor != Nu__null)) {
        id value = [[cursor car] evalWithContext:context];
        return nu_valueIsTrue(value) ? Nu__null : [symbolTable symbolWithString:@"t"];
    }
    return Nu__null;
}

@end


@interface Nu_pr_operator : NuOperator {}
@end

@implementation Nu_pr_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    if (!nu_valueIsTrue(get_symbol_value(@"debug-mode")))
        return Nu__null;
    
    NSString *string;
    id cursor = cdr;
    while (cursor && (cursor != Nu__null)) {
        string = [[[cursor car] evalWithContext:context] stringValue];
        pr(string);
        cursor = [cursor cdr];
    }
    return Nu__null;
}
@end


@interface Nu_prn_operator : NuOperator {}
@end

@implementation Nu_prn_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    if (!nu_valueIsTrue(get_symbol_value(@"debug-mode")))
        return Nu__null;
    
    NSString *string;
    id cursor = cdr;
    while (cursor && (cursor != Nu__null)) {
        string = [[[cursor car] evalWithContext:context] stringValue];
        prn(string);
        cursor = [cursor cdr];
    }
    return Nu__null;;
}
@end

@interface Nu_call_operator : NuOperator {}
@end

@implementation Nu_call_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id function = [[cdr car] evalWithContext:context];
    id arguments = [cdr cdr];
    id value = [function callWithArguments:arguments context:context];
    return value;
}

@end

@interface Nu_send_operator : NuOperator {}
@end

@implementation Nu_send_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id target = [[cdr car] evalWithContext:context];
    id message = [cdr cdr];
    id value = [target sendMessage:message withContext:context];
    return value;
}

@end

@interface Nu_progn_operator : NuOperator {}
@end

@implementation Nu_progn_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id value = Nu__null;
    id cursor = cdr;
    while (cursor && (cursor != Nu__null)) {
        value = [[cursor car] evalWithContext:context];
        cursor = [cursor cdr];
    }
    return value;
}

@end

@interface Nu_eval_operator : NuOperator {}
@end

@implementation Nu_eval_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id value = [[[cdr car] evalWithContext:context] evalWithContext:context];
    return value;
}

@end


@interface Nu_let_operator : NuOperator {}
@end

@implementation Nu_let_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    id arg_name = [[NuCell alloc] init];
    id arg_value = [[NuCell alloc] init];
    id body = [[NuCell alloc] init];
    
    id cursor = Nu__null;
    if (!cdr || (cdr == Nu__null)) {
    } else if ([[cdr car] atom]) {
        cursor = cdr;
        [arg_name setCar:[cursor car]];
        cursor = [cursor cdr];
        [arg_value setCar:[cursor car]];
        cursor = [cursor cdr];
    } else {
        cursor = [cdr car];
        if (cursor && (cursor != Nu__null)) {
            [arg_name setCar:[cursor car]];
            cursor = [cursor cdr];
            [arg_value setCar:[cursor car]];
            cursor = [cursor cdr];
            if (cursor && (cursor != Nu__null)) {
                id lst, lst_cursor;
                lst = lst_cursor = nucons1(nil, self);
                lst_cursor = nucons1(lst_cursor, cursor);
                [lst_cursor setCdr:[cdr cdr]];
                [body setCar:lst];
                cursor = body;
            } else {
                cursor = [cdr cdr];
            }
        }
    }
    id result = nil;
    if (cursor && (cursor != Nu__null)) {
        NuBlock *block = [[NuBlock alloc] initWithParameters:arg_name body:cursor context:context];
        result = [[block evalWithArguments:arg_value context:context] retain];
        [block release];
    }
    
    [arg_name release];
    [arg_value release];
    [body release];
    [pool drain];
    [result autorelease];
    return result;
}

@end

@interface Nu_class_operator : NuOperator {}
@end

@implementation Nu_class_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    id className = [cdr car];
    id body;
    Class newClass = nil;
    
    NuClass *childClass;
    //NSLog(@"class name: %@", className);
    if ([cdr cdr]
        && ([cdr cdr] != Nu__null)
        && [[[cdr cdr] car] isEqual: [symbolTable symbolWithString:@"is"]]
        ) {
        id parentName = [[[cdr cdr] cdr] car];
        //NSLog(@"parent name: %@", [parentName stringValue]);
        Class parentClass = NSClassFromString([parentName stringValue]);
        if (!parentClass)
            [NSException raise:@"NuUndefinedSuperclass" format:@"undefined superclass %@", [parentName stringValue]];
        
        
        newClass = objc_allocateClassPair(parentClass, [[className stringValue] cStringUsingEncoding:NSUTF8StringEncoding], 0);
        childClass = [NuClass classWithClass:newClass];
        [childClass setRegistered:NO];
        //NSLog(@"created class %@", [childClass name]);
        // it seems dangerous to call this here. Maybe it's better to wait until the new class is registered.
        if ([parentClass respondsToSelector:@selector(inheritedByClass:)]) {
            [parentClass inheritedByClass:childClass];
        }
        
        if (!childClass) {
            // This class may have already been defined previously
            // (perhaps by loading the same .nu file twice).
            // If so, the above call to objc_allocateClassPair() returns nil.
            // So if childClass is nil, it may be that the class was
            // already defined, so we'll try to find it and use it.
            Class existingClass = NSClassFromString([className stringValue]);
            if (existingClass) {
                childClass = [NuClass classWithClass:existingClass];
                //if (childClass)
                //    NSLog(@"Warning: attempting to re-define existing class: %@.  Ignoring.", [className stringValue]);
            }
        }
        
        body = [[[cdr cdr] cdr] cdr];
    }
    else {
        childClass = [NuClass classWithName:[className stringValue]];
        body = [cdr cdr];
    }
    if (!childClass)
        [NSException raise:@"NuUndefinedClass" format:@"undefined class %@", [className stringValue]];
    id result = nil;
    if (body && (body != Nu__null)) {
        NuBlock *block = [[NuBlock alloc] initWithParameters:Nu__null body:body context:context];
        [[block context]
         setPossiblyNullObject:childClass
         forKey:[symbolTable symbolWithString:@"_class"]];
        result = [block evalWithArguments:Nu__null context:Nu__null];
        [block release];
    }
    if (newClass && ([childClass isRegistered] == NO)) {
        [childClass registerClass];
    }
    return result;
}

@end



@interface Nu_ivar_operator : NuOperator {}
@end

@implementation Nu_ivar_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    NuClass *classWrapper = [context objectForKey:[symbolTable symbolWithString:@"_class"]];
    // this will only work if the class is unregistered...
    if ([classWrapper isRegistered]) {
        [NSException raise:@"NuIvarAddedTooLate" format:@"explicit instance variables must be added when a class is created and before any method declarations"];
    }
    Class classToExtend = [classWrapper wrappedClass];
    if (!classToExtend)
        [NSException raise:@"NuMisplacedDeclaration" format:@"instance variable declaration with no enclosing class declaration"];
    id cursor = cdr;
    while (cursor && (cursor != Nu__null)) {
        id variableType = [cursor car];
        cursor = [cursor cdr];
        id variableName = [cursor car];
        cursor = [cursor cdr];
        NSString *signature = signature_for_identifier(variableType, symbolTable);
        nu_class_addInstanceVariable_withSignature(classToExtend,
                                                   [[variableName stringValue] cStringUsingEncoding:NSUTF8StringEncoding],
                                                   [signature cStringUsingEncoding:NSUTF8StringEncoding]);
        //NSLog(@"adding ivar %@ with signature %@", [variableName stringValue], signature);
    }
    return Nu__null;
}

@end


@interface Nu_exit_operator : NuOperator {}
@end

@implementation Nu_exit_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    if (cdr && (cdr != Nu__null)) {
        int status = [[[cdr car] evalWithContext:context] intValue];
        exit(status);
    }
    else {
        exit (0);
    }
    return Nu__null;                              // we'll never get here.
}

@end

@interface Nu_sleep_operator : NuOperator {}
@end

@implementation Nu_sleep_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    int result = -1;
    if (cdr && (cdr != Nu__null)) {
        int seconds = [[[cdr car] evalWithContext:context] intValue];
        result = sleep(seconds);
    }
    else {
        [NSException raise: @"NuArityError" format:@"sleep expects 1 argument, got 0"];
    }
    return [NSNumber numberWithInt:result];
}

@end

@interface Nu_uname_operator : NuOperator {}
@end

@implementation Nu_uname_operator
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    struct utsname platform;
    int rc;
    
    rc = uname(&platform);
    if(rc == -1){
        return nil;
    }
    return [NSString stringWithUTF8String:platform.machine];
}

@end

@interface Nu_help_operator : NuOperator {}
@end

@implementation Nu_help_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id object = [[cdr car] evalWithContext:context];
    return [object help];
}

@end

@interface Nu_break_operator : NuOperator {}
@end

@implementation Nu_break_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    @throw [[[NuBreakException alloc] init] autorelease];
    return nil;                                   // unreached
}

@end

@interface Nu_continue_operator : NuOperator {}
@end

@implementation Nu_continue_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    @throw [[[NuContinueException alloc] init] autorelease];
    return nil;                                   // unreached
}

@end

@interface Nu_return_operator : NuOperator {}
@end

@implementation Nu_return_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id value = nil;
    if (cdr && cdr != Nu__null) {
        value = [[cdr car] evalWithContext:context];
    }
    @throw [[[NuReturnException alloc] initWithValue:value] autorelease];
    return nil;                                   // unreached
}

@end

@interface Nu_return_from_operator : NuOperator {}
@end

@implementation Nu_return_from_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id block = nil;
    id value = nil;
    id cursor = cdr;
    if (cursor && cursor != Nu__null) {
        block = [[cursor car] evalWithContext:context];
        cursor = [cursor cdr];
    }
    if (cursor && cursor != Nu__null) {
        value = [[cursor car] evalWithContext:context];
    }
    @throw [[[NuReturnException alloc] initWithValue:value blockForReturn:block] autorelease];
    return nil;                                   // unreached
}

@end

@interface Nu_version_operator : NuOperator {}
@end

@implementation Nu_version_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return nulist(nuint(NU_VERSION_MAJOR), nuint(NU_VERSION_MINOR), nuint(NU_VERSION_TWEAK));
}

@end

@interface Nu_min_operator : NuOperator {}
@end

@implementation Nu_min_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    if (cdr == Nu__null)
        [NSException raise: @"NuArityError" format:@"min expects at least 1 argument, got 0"];
    id smallest = [[cdr car] evalWithContext:context];
    id cursor = [cdr cdr];
    while (cursor && (cursor != Nu__null)) {
        id nextValue = [[cursor car] evalWithContext:context];
        if([smallest compare:nextValue] == 1) {
            smallest = nextValue;
        }
        cursor = [cursor cdr];
    }
    return smallest;
}

@end

@interface Nu_max_operator : NuOperator {}
@end

@implementation Nu_max_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    if (cdr == Nu__null)
        [NSException raise: @"NuArityError" format:@"max expects at least 1 argument, got 0"];
    id biggest = [[cdr car] evalWithContext:context];
    id cursor = [cdr cdr];
    while (cursor && (cursor != Nu__null)) {
        id nextValue = [[cursor car] evalWithContext:context];
        if([biggest compare:nextValue] == -1) {
            biggest = nextValue;
        }
        cursor = [cursor cdr];
    }
    return biggest;
}

@end

static id evaluatedArguments(id cdr, NSMutableDictionary *context)
{
    NuCell *evaluatedArguments = nil;
    id cursor = cdr;
    id outCursor = nil;
    while (cursor && (cursor != Nu__null)) {
        id nextValue = [[cursor car] evalWithContext:context];
        id newCell = [[[NuCell alloc] init] autorelease];
        [newCell setCar:nextValue];
        if (!outCursor) {
            evaluatedArguments = newCell;
        }
        else {
            [outCursor setCdr:newCell];
        }
        outCursor = newCell;
        cursor = [cursor cdr];
    }
    return evaluatedArguments;
}

@interface Nu_set_operator : NuOperator {}
@end

@implementation Nu_set_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [NSSet setWithList:evaluatedArguments(cdr, context)];
}

@end

@interface Nu_array_operator : NuOperator {}
@end

@implementation Nu_array_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [NSArray arrayWithList:evaluatedArguments(cdr, context)];
}

@end

@interface Nu_dict_operator : NuOperator {}
@end

@implementation Nu_dict_operator

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return [NSDictionary dictionaryWithList:evaluatedArguments(cdr, context)];
}

@end

@interface Nu_parse_operator : NuOperator {}
@end

@implementation Nu_parse_operator

// parse operator; parses a string into Nu code objects
- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    id parser = [[[NuParser alloc] init] autorelease];
    return [parser parse:[[cdr car] evalWithContext:context]];
}

@end

@interface Nu_imp_operator : NuOperator {}
@end

@implementation Nu_imp_operator

id make_imp_block(id cdr, NSMutableDictionary *context)
{
    void (^exception)(NSString *str) = ^(NSString *str) {
        [NSException raise:@"Nu_imp_operator" format:@"%@: %@", str, [cdr stringValue]];
    };
    
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    
    id returnType = [NSNull null];
    id argumentTypes = nil;
    id argumentNames = nil;
    id cursor = cdr;
    id argumentTypes_cursor = nil;
    id argumentNames_cursor = nil;
    
    if (nu_valueIsNull(cursor)) {
        exception(@"missing declaration");
        return nil;
    }
    
    // scan the return type
    if (![[cursor car] atom]) {
        exception(@"missing return type");
        return nil;
    }
    returnType = nucons1(nil, [cursor car]);
    prn([NSString stringWithFormat:@"returnType: %@", returnType]);
    cursor = [cursor cdr];

    if (!nu_valueIsNull(cursor) && ![[cursor car] atom]) {
        id args = [cursor car];
        while (!nu_valueIsNull(args)) {
            id type = [args car];
            prn([NSString stringWithFormat:@"type: %@", type]);
            args = [args cdr];
            if (nu_valueIsNull(args)) {
                exception(@"missing argument name");
                return nil;
            }
            id name = [args car];
            prn([NSString stringWithFormat:@"name: %@", name]);
            args = [args cdr];
            if (!nu_valueIsNull(type) && ![type atom]) {
                argumentTypes_cursor = nucons1(argumentTypes_cursor, type);
                if (!argumentTypes)
                    argumentTypes = argumentTypes_cursor;
            } else {
                exception(@"type should be enclosed in parenthesis");
                return nil;
            }
            argumentNames_cursor = nucons1(argumentNames_cursor, name);
            if (!argumentNames)
                argumentNames = argumentNames_cursor;
        }
    } else {
        exception(@"missing argument list");
        return nil;
    }
    cursor = [cursor cdr];
    if (nu_valueIsNull(cursor)) {
        exception(@"missing body");
        return nil;
    }
     
    NSMutableString *signature = nil;
    
    // build the signature, first get the return type
    signature = [[NSMutableString alloc] init];
    [signature appendString:signature_for_identifier(returnType, symbolTable)];
    
    // then add the common stuff
    [signature appendString:@"@:"];
    
    // then describe the arguments
    argumentTypes_cursor = argumentTypes;
    while (!nu_valueIsNull(argumentTypes_cursor)) {
        id typeIdentifier = [argumentTypes_cursor car];
        [signature appendString:signature_for_identifier(typeIdentifier, symbolTable)];
        argumentTypes_cursor = [argumentTypes_cursor cdr];
    }

    id body = cursor;
    NuBlock *block = [[[NuBlock alloc] initWithParameters:argumentNames body:body context:context] autorelease];
    return [[[NuImp alloc] initWithBlock:block signature:[signature cStringUsingEncoding:NSUTF8StringEncoding]] autorelease];
}

- (id) callWithArguments:(id)cdr context:(NSMutableDictionary *)context
{
    return make_imp_block(cdr, context);
}

@end



void set_symbol_value(NSString *name, id val)
{
    [(NuSymbol *)[[NuSymbolTable sharedSymbolTable] symbolWithString:name] setValue:val];
}

void install_builtin(NSString *namespace, NSString *key, id val)
{
    [[NuSymbolTable sharedSymbolTable] setBuiltin:val forKeyPath:[NSArray arrayWithObjects:namespace, key, nil]];
}

void install_builtin_and_symbol(NSString *namespace, NSString *key, id val)
{
    install_builtin(namespace, key, val);
    set_symbol_value(key, val);
}

void install_static_func(NSString *namespace, void *func, char *name, char *sig)
{
    install_builtin_and_symbol(namespace, [NSString stringWithUTF8String:name], [NuBridgedFunction staticFunction:func name:name signature:sig]);
}

void install_int(NSString *namespace, NSString *name, int val)
{
    install_builtin_and_symbol(namespace, name, [NSNumber numberWithInt:val]);
}

#define install(namespace, name, class) install_builtin_and_symbol(namespace, name, [[[class alloc] init] autorelease])

void load_builtins()
{
    install_builtin(@"nu", @"t", Nu__t);
    install_builtin(@"nu", @"nil", Nu__null);
    
    install(@"nu", @"car",      Nu_car_operator);
    install(@"nu", @"cdr",      Nu_cdr_operator);
    install(@"nu", @"atom",     Nu_atom_operator);
    install(@"nu", @"defined",  Nu_defined_operator);
    
    install(@"nu", @"cons",     Nu_cons_operator);
    install(@"nu", @"append",   Nu_append_operator);
    install(@"nu", @"list",     Nu_list_operator);
    
    install(@"nu", @"if",       Nu_if_operator);
    install(@"nu", @"case",     Nu_case_operator);
    install(@"nu", @"when",     Nu_when_operator);
    install(@"nu", @"unless",   Nu_unless_operator);
    install(@"nu", @"while",    Nu_while_operator);
    install(@"nu", @"until",    Nu_until_operator);
    install(@"nu", @"loop",     Nu_loop_operator);
    install(@"nu", @"break",    Nu_break_operator);
    install(@"nu", @"continue", Nu_continue_operator);
    install(@"nu", @"return",   Nu_return_operator);
    install(@"nu", @"return-from",   Nu_return_from_operator);
    
    install(@"nu", @"quote",    Nu_quote_operator);
    install(@"nu", @"parse",    Nu_parse_operator);
    install(@"nu", @"eval",     Nu_eval_operator);
    
    install(@"nu", @"context",  Nu_context_operator);
    install(@"nu", @"my",        Nu_local_operator);
    install(@"nu", @"=",       Nu_global_operator);
    install(@"nu", @"let",      Nu_let_operator);
    
    install(@"nu", @"progn",    Nu_progn_operator);
    
    install(@"nu", @"fn",       Nu_fn_operator);
    
    install(@"nu", @"mac",      Nu_macro_1_operator);
    install(@"nu", @"expand",   Nu_macrox_operator);
    
    install(@"nu", @"quasiquote",           Nu_quasiquote_operator);
    install(@"nu", @"quasiquote-eval",      Nu_quasiquote_eval_operator);
    install(@"nu", @"quasiquote-splice",    Nu_quasiquote_splice_operator);
    
    install(@"nu", @"call",     Nu_call_operator);
    install(@"nu", @"send",     Nu_send_operator);
    
    install(@"nu", @"eq",       Nu_eq_operator);
    install(@"nu", @"==",       Nu_eq_operator);
    install(@"nu", @"ne",       Nu_neq_operator);
    install(@"nu", @"!=",       Nu_neq_operator);
    install(@"nu", @"gt",       Nu_greaterthan_operator);
    install(@"nu", @">",        Nu_greaterthan_operator);
    install(@"nu", @"lt",       Nu_lessthan_operator);
    install(@"nu", @"<",        Nu_lessthan_operator);
    install(@"nu", @"ge",       Nu_gte_operator);
    install(@"nu", @">=",       Nu_gte_operator);
    install(@"nu", @"le",       Nu_lte_operator);
    install(@"nu", @"<=",       Nu_lte_operator);
    install(@"nu", @"eq*",      Nu_pointereq_operator);
    
    install(@"nu", @"+",        Nu_add_operator);
    install(@"nu", @"-",        Nu_subtract_operator);
    install(@"nu", @"*",        Nu_multiply_operator);
    install(@"nu", @"/",        Nu_divide_operator);
    install(@"nu", @"**",       Nu_exponentiation_operator);
    install(@"nu", @"%",        Nu_modulus_operator);
    
    install(@"nu", @"&",        Nu_bitwiseand_operator);
    install(@"nu", @"|",        Nu_bitwiseor_operator);
    install(@"nu", @"<<",       Nu_leftshift_operator);
    install(@"nu", @">>",       Nu_rightshift_operator);
    
    install(@"nu", @"and",      Nu_and_operator);
    install(@"nu", @"or",       Nu_or_operator);
    install(@"nu", @"not",      Nu_not_operator);
    
    install(@"nu", @"min",      Nu_min_operator);
    install(@"nu", @"max",      Nu_max_operator);
    
    install(@"nu", @"set",      Nu_set_operator);
    install(@"nu", @"array",    Nu_array_operator);
    install(@"nu", @"dict",     Nu_dict_operator);
    
    install(@"nu", @"class",    Nu_class_operator);
    install(@"nu", @"ivar",     Nu_ivar_operator);
    
    install(@"nu", @"try",      Nu_try_operator);
    install(@"nu", @"throw",    Nu_throw_operator);
    install(@"nu", @"synchronized", Nu_synchronized_operator);
    
    install(@"nu", @"pr",       Nu_pr_operator);
    install(@"nu", @"prn",      Nu_prn_operator);
    install(@"nu", @"uname",    Nu_uname_operator);
    install(@"nu", @"exit",     Nu_exit_operator);
    install(@"nu", @"sleep",    Nu_sleep_operator);
    install(@"nu", @"help",     Nu_help_operator);
    install(@"nu", @"version",  Nu_version_operator);
    
    install(@"nu", @"imp", Nu_imp_operator);
    
#include "builtin_enum.c"
#include "builtin_curl.c"
    
    install_builtin(@"math", @"M_PI", [NSNumber numberWithDouble:M_PI]);
    install_builtin(@"cocoa", @"CGAffineTransformIdentity", get_nu_value_from_objc_value(&CGAffineTransformIdentity, "{CGAffineTransform=ffffff}"));
    
    install_static_func(@"math", cosf, "cos", "ff");
    install_static_func(@"math", sinf, "sin", "ff");
    install_static_func(@"math", sqrt, "sqrt", "dd");
    install_static_func(@"math", cbrt, "cbrt", "dd");
    install_static_func(@"math", exp, "exp", "dd");
    install_static_func(@"math", exp2, "exp2", "dd");
    install_static_func(@"math", log, "log", "dd");
    install_static_func(@"math", log2, "log2", "dd");
    install_static_func(@"math", log10, "log10", "dd");
    install_static_func(@"math", floor, "floor", "dd");
    install_static_func(@"math", ceil, "ceil", "dd");
    install_static_func(@"math", round, "round", "dd");
    install_static_func(@"math", pow, "pow", "ddd");
    install_static_func(@"math", fabs, "fabs", "dd");
    install_static_func(@"math", random, "random", "l");
    install_static_func(@"math", srandom, "srandom", "vI");
    
    install_static_func(@"nu", get_docs_path, "docs-path", "@");
    install_static_func(@"nu", path_in_docs, "path-in-docs", "@@");
    install_static_func(@"nu", path_to_namespace, "path-to-namespace", "@@");
    install_static_func(@"nu", path_to_symbol, "path-to-symbol", "@@@");
    install_static_func(@"nu", read_symbol, "read-symbol", "@@@");
    install_static_func(@"nu", write_symbol, "write-symbol", "i@@@");
//    install_static_func(@"nu", symbol_namespace, "symbol-namespace", "@@");
    install_static_func(@"nu", clear_symbol, "clear-symbol", "i@");
    install_static_func(@"nu", show_alert, "show-alert", "v@@@");
    install_static_func(@"nu", nu_namespaces, "namespaces", "@");
    
    install_static_func(@"cocoa", UIGraphicsGetCurrentContext, "UIGraphicsGetCurrentContext", "*");
    install_static_func(@"cocoa", UIGraphicsBeginImageContextWithOptions, "UIGraphicsBeginImageContextWithOptions", "v{CGSize=ff}if");
    install_static_func(@"cocoa", UIGraphicsEndImageContext, "UIGraphicsEndImageContext", "v");
    install_static_func(@"cocoa", UIGraphicsGetImageFromCurrentImageContext, "UIGraphicsGetImageFromCurrentImageContext", "@");
    install_static_func(@"cocoa", UIImagePNGRepresentation, "UIImagePNGRepresentation", "@@");

    NSLog(@"loading builtin_rom...");
#include "builtin_const.c"
#include "builtin_func.c"
#include "builtin_boot.c"
#include "builtin_rom.c"
}

@implementation PCRE
@synthesize pattern = _pattern;

+ (id)regexWithPattern:(NSString *)pattern options:(int)options
{
    return [[[self alloc] initWithPattern:pattern options:options] autorelease];
}

- (void)dealloc
{
    if (_re) {
        pcre_free(_re);
        _re = NULL;
    }
    [super dealloc];
}

- (id)initWithPattern:(NSString *)pattern options:(int)options
{
    self = [super init];
    if (self) {
        const char *error;
        int erroffset;
        self.pattern = pattern;
        _re = pcre_compile(
                           [self.pattern cStringUsingEncoding:NSUTF8StringEncoding],
                           PCRE_UTF8|options,
                           &error,
                           &erroffset,
                           NULL);
        if (!_re) {
            [NSException raise:@"NuInvalidRegexPattern"
                        format:@"Error while compiling regex pattern %@: %s",
             pattern, error];
        }
    }
    return self;
}

- (id)evalWithArguments:(id)cdr context:(NSMutableDictionary *)calling_context
{
    if (!_re)
        return Nu__null;
    
    id cursor = cdr;
    if (!cursor || (cursor == Nu__null)) {
        return Nu__null;
    }
    
    NSString *str;
    str = [[[cursor car] evalWithContext:calling_context] stringValue];
    char *cstr = (char *)[str cStringUsingEncoding:NSUTF8StringEncoding];
    int rc;
    int ovector[30];
    rc = pcre_exec(
                   _re,             /* result of pcre_compile() */
                   NULL,           /* we didn't study the pattern */
                   cstr,  /* the subject string */
                   [str length],             /* the length of the subject string */
                   0,              /* start at offset 0 in the subject */
                   0,              /* default options */
                   ovector,        /* vector of integers for substring information */
                   30);            /* number of elements (NOT size in bytes) */
    
    if (rc < 0)
        return Nu__null;
    
    int nelts = rc*2;
    if (!nelts)
        nelts = 20;
    
    id head = nil, tail = nil;
    for(int i=0; i<nelts; i+=2) {
        id obj = [[[NSString alloc] initWithBytes:cstr+ovector[i] length:ovector[i+1]-ovector[i] encoding:NSUTF8StringEncoding] autorelease];
        tail = nucons1(tail, obj);
        if (!head)
            head = tail;
    }
    
    return head;
}

@end

@implementation NuCurl
@synthesize data = _data;
@synthesize metadata = _metadata;

size_t nucurl_read_helper( void *ptr, size_t size, size_t nmemb, void *userdata)
{
    NuCurl *self = userdata;
    if (!self.uploadData) {
        return 0;
    }
    char *bytes = (char *)self.uploadData.bytes;
    int len = self.uploadData.length;
    int n = size * nmemb;
    int remaining = len - self.uploadDataIndex;
    if (remaining < n) {
        n = remaining;
    }
    memcpy(ptr, bytes + self.uploadDataIndex, n);
    self.uploadDataIndex += n;
    return n;
}

size_t nucurl_write_helper( char *ptr, size_t size, size_t nmemb, void *userdata)
{
    NuCurl *self = userdata;
    NSLog(@"nucurl_write_helper %ld bytes", size*nmemb);
    if (self->_writefp) {
        return fwrite(ptr, size, nmemb, self->_writefp);
    }
    size_t n = size*nmemb;
    [self.data appendBytes:ptr length:n];
    return n;
}

int nucurl_debug_helper(CURL *curl, curl_infotype type, char *p, size_t n, void *user)
{
    NuCurl *self = user;
    [self.metadata appendBytes:p length:n];
    return 0;
}

- (void)dealloc
{
    if (_curl) {
        curl_easy_cleanup(_curl);
        _curl = NULL;
    }
    self.error = nil;
    self.data = nil;
    self.metadata = nil;
    [super dealloc];
}



- (id)init
{
    static BOOL is_initialised = NO;
    self = [super init];
    if (self) {
        if (!is_initialised) {
            if (curl_global_init(CURL_GLOBAL_ALL)) {
                return nil;
            }
            is_initialised = YES;
        }
        _curl = curl_easy_init();
        if (!_curl) {
            return nil;
        }
        self.uploadDataIndex = 0;
        self.data = [[[NSMutableData alloc] init] autorelease];
        self.metadata = [[[NSMutableData alloc] init] autorelease];
        curl_easy_setopt(_curl, CURLOPT_ERRORBUFFER, _errorbuffer);
        curl_easy_setopt(_curl, CURLOPT_READFUNCTION, nucurl_read_helper);
        curl_easy_setopt(_curl, CURLOPT_READDATA, self);
        curl_easy_setopt(_curl, CURLOPT_WRITEFUNCTION, nucurl_write_helper);
        curl_easy_setopt(_curl, CURLOPT_WRITEDATA, self);
        curl_easy_setopt(_curl, CURLOPT_DEBUGFUNCTION, nucurl_debug_helper);
        curl_easy_setopt(_curl, CURLOPT_DEBUGDATA, self);
    }
    return self;
}

- (id)errorbuffer { return [NSString stringWithUTF8String:_errorbuffer]; }

- (void)error:(NSString *)str val:(int)val
{
    self.error = [NSString stringWithFormat:@"%@ returned %d '%s', errorbuffer = '%s'", str, val, curl_easy_strerror(val), _errorbuffer];
}

- (void)reset
{
    if (!_curl)
        return;
    curl_easy_reset(_curl);
}

- (id)pause:(int)bitmask
{
    if (!_curl)
        return Nu__null;
    int val = curl_easy_pause(_curl, bitmask);
    if (val == 0)
        return Nu__t;
    [self error:@"curl_easy_pause" val:val];
    return Nu__null;
}

- (id)perform
{
    if (!_curl)
        return Nu__null;
    [self.data setLength:0];
    [self.metadata setLength:0];
    int val = curl_easy_perform(_curl);
    if (val == 0) {
        return self.data;
    }
    [self error:@"curl_easy_perform" val:val];
    return Nu__null;
}

- (id)save:(NSString *)path
{
    if (!_curl)
        return Nu__null;
    _writefp = fopen([path UTF8String], "w");
    if (!_writefp) {
        self.error = [NSString stringWithFormat:@"unable to write to file '%@'", path];
        return Nu__null;
    }
    int val = curl_easy_perform(_curl);
    fclose(_writefp);
    _writefp = NULL;
    if (val == 0)
        return Nu__t;
    return Nu__null;
}

- (id)curlEasySetopt:(int)opt param:(id)param
{
    if ([param isKindOfClass:[NSNumber class]]) {
        int val = curl_easy_setopt(_curl, opt, [param longValue]);
        if (val == 0) {
            return self;
        }
        [self error:@"curl_easy_setopt" val:val];
        return Nu__null;
    } else if ([param isKindOfClass:[NSString class]]) {
        int val = curl_easy_setopt(_curl, opt, [param cStringUsingEncoding:NSUTF8StringEncoding]);
        if (val == 0) {
            return self;
        }
        [self error:@"curl_easy_setopt" val:val];
        return Nu__null;
    }
    return Nu__null;
}

- (id) handleUnknownMessage:(NuCell *) method withContext:(NSMutableDictionary *) context
{
    id m = [[method car] evalWithContext:context];
    if (!_curl || [m isKindOfClass:[NSNumber class]]) {
        int mm = [m intValue];
        id param = [[[method cdr] car] evalWithContext:context];
        return [self curlEasySetopt:mm param:param];
    }
    else {
        return [super handleUnknownMessage:method withContext:context];
    }
}
@end


