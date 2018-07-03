// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelGhostingMaskLayer.h"

#import "STULabel/STUTextLink-Internal.hpp"

#import "CoreGraphicsUtils.hpp"

using namespace stu_label;

@implementation STULabelGhostingMaskLayer {
  CGRect _maskedLayerFrame;
  STUTextLinkArray* _links;
  NSMutableDictionary<STUTextLink*, id>* _ghostedLinkPaths;
  NSMutableArray<STUTextLink*>* _vanishedGhostedLinks;
  size_t _ghostedLinkCount;
}

- (instancetype)init {
  if (self = [super init]) {
    self.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.5].CGColor;
    self.fillColor = UIColor.blackColor.CGColor;
  }
  return self;
}

- (void)setMaskedLayerFrame:(CGRect)maskedLayerFrame links:(STUTextLinkArray*)links {
  _maskedLayerFrame = maskedLayerFrame;
  _links = links;
  self.frame = CGRect{{}, maskedLayerFrame.size};
  if (_ghostedLinkCount != 0) {
    NSArray<STUTextLink*>* const oldGhostedLinks = _ghostedLinkPaths.allKeys;
    [_ghostedLinkPaths removeAllObjects];
    NSArray<STUTextLink*>* const oldVanishedLinks = [_vanishedGhostedLinks copy];
    [_vanishedGhostedLinks removeAllObjects];
    for (STUTextLink* const oldLink in oldGhostedLinks) {
      [self stu_addGhostedLink:oldLink];
    }
    for (STUTextLink* const oldLink in oldVanishedLinks) {
      [self stu_addGhostedLink:oldLink];
    }
  }
  [self setNeedsDisplay];
}

- (void)stu_addGhostedLink:(STUTextLink*)newLink {
  _ghostedLinkCount += 1;
  STUTextLink* const link = [_links linkMatchingLink:newLink];
  if (!link) {
    [_vanishedGhostedLinks addObject:newLink];
    return;
  }
  // For text whose image bounds extend beyond its layout bounds, such as italic or calligraphic
  // text, it would look better if we masked the actual path of the text content instead of the text
  // rects path. Unfortunately there's no simple way to invert a CALayer's mask on iOS, so we can't
  // just insert sublayers for the links into the mask layer. Other approaches are more complicated
  // and may not scale to arbitrarily large link texts. One approach that may work is using a tiled
  // layer for the mask with a drawing block that first draws the ghosted ranges and then inverts
  // the alpha channel.
  const CGAffineTransform translation = CGAffineTransformMakeTranslation(
                                          -_maskedLayerFrame.origin.x, -_maskedLayerFrame.origin.y);
  const CGPathRef linkPath = [link createPathWithEdgeInsets:UIEdgeInsets{}
                                               cornerRadius:0
                    extendTextLinesToCommonHorizontalBounds:false
                                           fillTextLineGaps:true
                                                  transform:&translation];
  if (!_ghostedLinkPaths) {
    _ghostedLinkPaths = [[NSMutableDictionary alloc] initWithCapacity:4];
  }
  _ghostedLinkPaths[link] = (__bridge id)linkPath;
  CFRelease(linkPath);
}

- (void)ghostLink:(STUTextLink*)link {
  [self stu_addGhostedLink:link];
  [self setNeedsDisplay];
}

- (bool)unghostLink:(STUTextLink*)link {
  STUTextLink* const localLink = [_links linkMatchingLink:link];
  if (localLink) {
    STU_DEBUG_ASSERT(_ghostedLinkPaths[localLink]);
    [_ghostedLinkPaths removeObjectForKey:localLink];
    [self setNeedsDisplay];
  } else {
    const Optional<Int> index = indexOfMatchingLink(_vanishedGhostedLinks, link);
    STU_DEBUG_ASSERT(index != none);
    if (index == none) return false;
    [_vanishedGhostedLinks removeObjectAtIndex:sign_cast(*index)];
  }
  return --_ghostedLinkCount == 0;
}

- (bool)hasGhostedLink:(STUTextLink*)link {
  STUTextLink* const localLink = [_links linkMatchingLink:link];
  return localLink ? [_ghostedLinkPaths objectForKey:localLink] != nil
                   : indexOfMatchingLink(_vanishedGhostedLinks, link) != none;
}

- (void)display {
  const CGMutablePathRef path = CGPathCreateMutable();

  addReversedRectPath(*path, nil, CGRect{{}, _maskedLayerFrame.size});

  NSEnumerator* const enumerator = _ghostedLinkPaths.objectEnumerator;
  while (const CGPathRef linkPath = (__bridge CGPathRef)[enumerator nextObject]) {
    CGPathAddPath(path, nil, linkPath);
  }

  self.path = path;

  CFRelease(path);
}

@end
