//
//  RSParsedFeed.m
//  RSXML
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSParsedFeed.h"

@implementation RSParsedFeed

- (instancetype)initWithURLString:(NSString *)urlString title:(NSString *)title link:(NSString *)link articles:(NSSet *)articles {
	
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_urlString = urlString;
	_title = title;
	_link = link;
	_articles = articles;
	
	return self;
}


@end
