/*
	An implementation of the Ruby on Rails inflector in Objective-C.
	Ciarán Walsh, 2008

	See README.mdown for usage info.

	Use ⌃R on the following line in TextMate to run tests:
	g++ "$TM_FILEPATH" "$(dirname "$TM_FILEPATH")"/RegexKitLite/RegexKitLite.m -licucore -DTEST_INFLECTOR -framework Cocoa -o "${TM_FILEPATH%.*}" && ("${TM_FILEPATH%.*}"; rm "${TM_FILEPATH%.*}")
*/

#import "CWInflector.h"

@implementation CWInflector

+ (CWInflector*)inflector
{
        
	static dispatch_once_t predicate;
    static CWInflector *_shared = nil;
    
    dispatch_once(&predicate, ^{
        _shared = [[self alloc] init];
    });
    
    return _shared;
}

- (id)init
{
	self = [super init];
    if (self) {
        
		plurals      = [NSMutableArray new];
		singulars    = [NSMutableArray new];
		uncountables = [NSMutableArray new];
		[self addInflectionsFromFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"inflections" ofType:@"plist"]];
	}

	return self;
}

- (void)addInflectionsFromFile:(NSString*)path;
{
	NSDictionary* inflections = [NSDictionary dictionaryWithContentsOfFile:path];
	[plurals addObjectsFromArray:inflections[@"plurals"]];
	[singulars addObjectsFromArray:inflections[@"singulars"]];
	[uncountables addObjectsFromArray:inflections[@"uncountables"]];
    
	for(NSArray* irregular in inflections[@"irregulars"])
		[self addIrregular:irregular[0] plural:irregular[1]];
}

- (void)addIrregular:(NSString*)singular plural:(NSString*)plural;
{
	NSString* pattern      = [NSString stringWithFormat:@"(%C)%@$", [singular characterAtIndex:0], [singular substringFromIndex:1]];
	NSString* substitution = [NSString stringWithFormat:@"$1%@", [plural substringFromIndex:1]];
	[self addPluralPattern:pattern substitution:substitution];

	pattern      = [NSString stringWithFormat:@"(%C)%@$", [plural characterAtIndex:0], [plural substringFromIndex:1]];
	substitution = [NSString stringWithFormat:@"$1%@", [singular substringFromIndex:1]];
	[self addSingularPattern:pattern substitution:substitution];
}

- (void)addPluralPattern:(NSString*)pattern substitution:(NSString*)substitution;
{
	[plurals addObject:@[pattern,substitution]];
}

- (void)addSingularPattern:(NSString*)pattern substitution:(NSString*)substitution;
{
	[singulars addObject:@[pattern,substitution]];
}

- (NSString*)pluralFormOf:(NSString*)singular;
{
	if([uncountables containsObject:[singular lowercaseString]])
		return singular;

	NSEnumerator* enumerator = [plurals reverseObjectEnumerator];
	while(NSArray* conversion = [enumerator nextObject])
	{
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:conversion[0] options:0 error:nil];
        
        NSString *result = [expression stringByReplacingMatchesInString:singular options:0 range:NSMakeRange(0, [singular length]) withTemplate:conversion[1]];

		if(result && ![result isEqualToString:singular])
			return result;
	}
	return singular;
}

- (NSString*)singularFormOf:(NSString*)plural;
{
	if([uncountables containsObject:[plural lowercaseString]])
		return plural;

	NSEnumerator* enumerator = [singulars reverseObjectEnumerator];
	while(NSArray* conversion = [enumerator nextObject])
	{
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:conversion[0] options:0 error:nil];
        
        NSString *result = [expression stringByReplacingMatchesInString:plural options:0 range:NSMakeRange(0, [plural length]) withTemplate:conversion[1]];

		if(result && ![result isEqualToString:plural])
			return result;
	}
	return plural;
}

- (NSString*)humanizedFormOf:(NSString*)word;
{
	NSString* result = word;
	if([result length] > 3 && [[result substringFromIndex:([result length]-3)] isEqualToString:@"_id"])
		result = [result substringToIndex:([result length]-3)];
	result = [result stringByReplacingOccurrencesOfString:@"_" withString:@" "];
	return [[[result substringToIndex:1] uppercaseString] stringByAppendingString:[result substringFromIndex:1]];
}
@end

@implementation NSString (InflectorAdditions)
- (NSString*)pluralForm    { return [[CWInflector inflector] pluralFormOf:self];    }
- (NSString*)singularForm  { return [[CWInflector inflector] singularFormOf:self];  }
- (NSString*)humanizedForm { return [[CWInflector inflector] humanizedFormOf:self]; }
@end

#ifdef TEST_INFLECTOR
#include <assert.h>

int main() {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	assert([CWInflector inflector] == [CWInflector inflector]);

	NSString* plistPath = [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"inflections.plist"];
	[[CWInflector inflector] addInflectionsFromFile:plistPath];

	assert([[[CWInflector inflector] pluralFormOf:@"Cat"] isEqualToString:@"Cats"]);
	assert([[[CWInflector inflector] pluralFormOf:@"bus"] isEqualToString:@"buses"]);
	assert([[[CWInflector inflector] pluralFormOf:@"man"] isEqualToString:@"men"]);

	assert([[@"Sheep" pluralForm] isEqualToString:@"Sheep"]);

	assert([[[CWInflector inflector] singularFormOf:@"Cats"] isEqualToString:@"Cat"]);
	assert([[[CWInflector inflector] singularFormOf:@"buses"] isEqualToString:@"bus"]);
	assert([[[CWInflector inflector] singularFormOf:@"men"] isEqualToString:@"man"]);

	assert([[@"Sheep" singularForm] isEqualToString:@"Sheep"]);

	assert(![[@"cactus" pluralForm] isEqualToString:@"cacti"]);
	[[CWInflector inflector] addIrregular:@"cactus" plural:@"cacti"];
	assert([[@"cactus" pluralForm] isEqualToString:@"cacti"]);

	printf("Tests passed\n");

	[pool release];
	return 0;
}
#endif
