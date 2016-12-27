//
//  RSOPMLParser.m
//  RSXML
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSOPMLParser.h"
#import <libxml/xmlstring.h>
#import "RSXMLData.h"
#import "RSSAXParser.h"
#import "RSOPMLItem.h"
#import "RSOPMLDocument.h"
#import "RSOPMLAttributes.h"
#import "RSXMLError.h"


void RSParseOPML(RSXMLData *xmlData, RSParsedOPMLBlock callback) {

	NSCParameterAssert(xmlData);
	NSCParameterAssert(callback);

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

		@autoreleasepool {

			RSOPMLParser *parser = [[RSOPMLParser alloc] initWithXMLData:xmlData];

			RSOPMLDocument *document = parser.OPMLDocument;
			NSError *error = parser.error;

			dispatch_async(dispatch_get_main_queue(), ^{

				callback(document, error);
			});
		}
	});
}


@interface RSOPMLParser () <RSSAXParserDelegate>

@property (nonatomic, readwrite) RSOPMLDocument *OPMLDocument;
@property (nonatomic, readwrite) NSError *error;
@property (nonatomic) NSMutableArray *itemStack;

@end


@implementation RSOPMLParser


#pragma mark - Init

- (instancetype)initWithXMLData:(RSXMLData *)XMLData {

	self = [super init];
	if (!self) {
		return nil;
	}

	[self parse:XMLData];

	return self;
}


#pragma mark - Private

- (void)parse:(RSXMLData *)XMLData {

	@autoreleasepool {

		if (![self canParseData:XMLData.data]) {

			NSString *filename = nil;
			NSURL *url = [NSURL URLWithString:XMLData.urlString];
			if (url && url.isFileURL) {
				filename = url.path.lastPathComponent;
			}
			if ([XMLData.urlString hasPrefix:@"http"]) {
				filename = XMLData.urlString;
			}
			if (!filename) {
				filename = XMLData.urlString;
			}
			self.error = RSOPMLWrongFormatError(filename);
			return;
		}
		
		RSSAXParser *parser = [[RSSAXParser alloc] initWithDelegate:self];

		self.itemStack = [NSMutableArray new];
		self.OPMLDocument = [RSOPMLDocument new];
		[self pushItem:self.OPMLDocument];

		[parser parseData:XMLData.data];
		[parser finishParsing];
	}
}

- (BOOL)canParseData:(NSData *)d {

	// Check for <opml and <outline near the top.

	@autoreleasepool {

		NSString *s = [[NSString alloc] initWithBytesNoCopy:(void *)d.bytes length:d.length encoding:NSUTF8StringEncoding freeWhenDone:NO];
		if (!s) {
			NSDictionary *options = @{NSStringEncodingDetectionSuggestedEncodingsKey : @[@(NSUTF8StringEncoding)]};
			(void)[NSString stringEncodingForData:d encodingOptions:options convertedString:&s usedLossyConversion:nil];
		}
		if (!s) {
			return NO;
		}

		static const NSInteger numberOfCharactersToSearch = 4096;
		NSRange rangeToSearch = NSMakeRange(0, numberOfCharactersToSearch);
		if (s.length < numberOfCharactersToSearch) {
			rangeToSearch.length = s.length;
		}

		NSRange opmlRange = [s rangeOfString:@"<opml" options:NSCaseInsensitiveSearch range:rangeToSearch];
		if (opmlRange.length < 1) {
			return NO;
		}

		NSRange outlineRange = [s rangeOfString:@"<outline" options:NSLiteralSearch range:rangeToSearch];
		if (outlineRange.length < 1) {
			return NO;
		}

		if (outlineRange.location < opmlRange.location) {
			return NO;
		}
	}

	return YES;
}

- (void)pushItem:(RSOPMLItem *)item {

	[self.itemStack addObject:item];
}


- (void)popItem {

	NSAssert(self.itemStack.count > 0, nil);

	/*If itemStack is empty, bad things are happening.
	 But we still shouldn't crash in production.*/

	if (self.itemStack.count > 0) {
		[self.itemStack removeLastObject];
	}
}


- (RSOPMLItem *)currentItem {
	
	return self.itemStack.lastObject;
}


#pragma mark - RSSAXParserDelegate

static const char *kOutline = "outline";
static const char kOutlineLength = 8;

- (void)saxParser:(RSSAXParser *)SAXParser XMLStartElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri numberOfNamespaces:(NSInteger)numberOfNamespaces namespaces:(const xmlChar **)namespaces numberOfAttributes:(NSInteger)numberOfAttributes numberDefaulted:(int)numberDefaulted attributes:(const xmlChar **)attributes {

	if (!RSSAXEqualTags(localName, kOutline, kOutlineLength)) {
		return;
	}

	RSOPMLItem *item = [RSOPMLItem new];
	item.attributes = [SAXParser attributesDictionary:attributes numberOfAttributes:numberOfAttributes];

	[[self currentItem] addChild:item];
	[self pushItem:item];
}


- (void)saxParser:(RSSAXParser *)SAXParser XMLEndElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri {

	if (RSSAXEqualTags(localName, kOutline, kOutlineLength)) {
		[self popItem];
	}
}


static const char *kText = "text";
static const NSInteger kTextLength = 5;

static const char *kTitle = "title";
static const NSInteger kTitleLength = 6;

static const char *kDescription = "description";
static const NSInteger kDescriptionLength = 12;

static const char *kType = "type";
static const NSInteger kTypeLength = 5;

static const char *kVersion = "version";
static const NSInteger kVersionLength = 8;

static const char *kHTMLURL = "htmlUrl";
static const NSInteger kHTMLURLLength = 8;

static const char *kXMLURL = "xmlUrl";
static const NSInteger kXMLURLLength = 7;

- (NSString *)saxParser:(RSSAXParser *)SAXParser internedStringForName:(const xmlChar *)name prefix:(const xmlChar *)prefix {

	if (prefix) {
		return nil;
	}

	size_t nameLength = strlen((const char *)name);

	if (nameLength == kTextLength - 1) {
		if (RSSAXEqualTags(name, kText, kTextLength)) {
			return OPMLTextKey;
		}
		if (RSSAXEqualTags(name, kType, kTypeLength)) {
			return OPMLTypeKey;
		}
	}

	else if (nameLength == kTitleLength - 1) {
		if (RSSAXEqualTags(name, kTitle, kTitleLength)) {
			return OPMLTitleKey;
		}
	}

	else if (nameLength == kXMLURLLength - 1) {
		if (RSSAXEqualTags(name, kXMLURL, kXMLURLLength)) {
			return OPMLXMLURLKey;
		}
	}

	else if (nameLength == kVersionLength - 1) {
		if (RSSAXEqualTags(name, kVersion, kVersionLength)) {
			return OPMLVersionKey;
		}
		if (RSSAXEqualTags(name, kHTMLURL, kHTMLURLLength)) {
			return OPMLHMTLURLKey;
		}
	}

	else if (nameLength == kDescriptionLength - 1) {
		if (RSSAXEqualTags(name, kDescription, kDescriptionLength)) {
			return OPMLDescriptionKey;
		}
	}

	return nil;
}


static const char *kRSSUppercase = "RSS";
static const char *kRSSLowercase = "rss";
static const NSUInteger kRSSLength = 3;
static NSString *RSSUppercaseValue = @"RSS";
static NSString *RSSLowercaseValue = @"rss";
static NSString *emptyString = @"";

static BOOL equalBytes(const void *bytes1, const void *bytes2, NSUInteger length) {

	return memcmp(bytes1, bytes2, length) == 0;
}

- (NSString *)saxParser:(RSSAXParser *)SAXParser internedStringForValue:(const void *)bytes length:(NSUInteger)length {


	if (length < 1) {
		return emptyString;
	}

	if (length == kRSSLength) {

		if (equalBytes(bytes, kRSSUppercase, kRSSLength)) {
			return RSSUppercaseValue;
		}
		else if (equalBytes(bytes, kRSSLowercase, kRSSLength)) {
			return RSSLowercaseValue;
		}

	}

	return nil;
}


@end
