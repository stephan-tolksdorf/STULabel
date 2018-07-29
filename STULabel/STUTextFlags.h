// Copyright 2017 Stephan Tolksdorf

#import "STUDefines.h"

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(uint16_t, STUTextFlags) {
  STUTextHasLink           = 1 <<  0,
  STUTextHasBackground     = 1 <<  1,
  STUTextHasShadow         = 1 <<  2,
  STUTextHasUnderline      = 1 <<  3,
  STUTextHasStrikethrough  = 1 <<  4,
  STUTextHasStroke         = 1 <<  5,
  STUTextHasAttachment     = 1 <<  6,
  STUTextHasBaselineOffset = 1 <<  7,
  STUTextMayNotBeGrayscale = 1 <<  8,
  STUTextUsesExtendedColor = 1 <<  9,

  STUTextDecorationFlags  = STUTextHasBackground
                          | STUTextHasShadow
                          | STUTextHasUnderline
                          | STUTextHasStrikethrough
                          | STUTextHasStroke
};

enum {
  STUTextFlagsBitSize STU_SWIFT_UNAVAILABLE = 10
};
