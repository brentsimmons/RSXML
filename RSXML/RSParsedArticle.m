//
//  RSParsedArticle.m
//  RSXML
//
//  Created by Brent Simmons on 12/6/14.
//  Copyright (c) 2014 Ranchero Software LLC. All rights reserved.
//

#import "RSParsedArticle.h"
#import "RSXMLInternal.h"


@implementation RSParsedArticle


#pragma mark - Init

- (instancetype)initWithFeedURL:(NSString *)feedURL {
	
	NSParameterAssert(feedURL != nil);
	
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_feedURL = feedURL;
	_dateParsed = [NSDate date];
	
	return self;
}


#pragma mark - Accessors

- (NSString *)articleID {
	
	if (!_articleID) {
		_articleID = self.calculatedUniqueID;
	}
	
	return _articleID;
}


- (NSString *)calculatedUniqueID {

	/*guid+feedID, or a combination of properties when no guid. Then hash the result.
		In general, feeds should have guids. When they don't, re-runs are very likely,
		because there's no other 100% reliable way to determine identity.*/

	NSMutableString *s = [NSMutableString stringWithString:@""];
	
	NSString *datePublishedTimeStampString = nil;
	if (self.datePublished) {
		datePublishedTimeStampString = [NSString stringWithFormat:@"%.0f", self.datePublished.timeIntervalSince1970];
	}
	
	if (!RSXMLStringIsEmpty(self.guid)) {
		[s appendString:self.guid];
	}

	else if (!RSXMLStringIsEmpty(self.link) && self.datePublished != nil) {
		[s appendString:self.link];
		[s appendString:datePublishedTimeStampString];
	}

	else if (!RSXMLStringIsEmpty(self.title) && self.datePublished != nil) {
		[s appendString:self.title];
		[s appendString:datePublishedTimeStampString];
	}

	else if (self.datePublished != nil) {
		[s appendString:datePublishedTimeStampString];
	}

	else if (!RSXMLStringIsEmpty(self.link)) {
		[s appendString:self.link];
	}

	else if (!RSXMLStringIsEmpty(self.title)) {
		[s appendString:self.title];
	}
	
	else if (!RSXMLStringIsEmpty(self.body)) {
		[s appendString:self.body];
	}

	NSAssert(!RSXMLStringIsEmpty(self.feedURL), nil);
	[s appendString:self.feedURL];

	return [s rsxml_md5HashString];
}

- (void)calculateArticleID {
	
	(void)self.articleID;
}

@end

