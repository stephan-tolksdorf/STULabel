// Copyright 2018 Stephan Tolksdorf

#include "Localized.hpp"

#include "STULabel/STULabel.h"

namespace stu_label {

NSString* appLocalization;
NSString* systemLocalization;
NSDictionary<NSString*, NSString*>* localizedStrings_app;
NSDictionary<NSString*, NSString*>* localizedStrings_system;

static void initializeIfNecessary() {
  static dispatch_once_t once;
  dispatch_once_f(&once, nullptr, [](void *) {
    NSString* const bundlePath = [[NSBundle bundleForClass:STULabel.class]
                                    pathForResource:@"STULabelResources" ofType:@"bundle"];
    NSBundle* const bundle = bundlePath ? [NSBundle bundleWithPath:bundlePath] : nil;
    STU_CHECK_MSG(bundle != nil, "Failed to load STULabelResources.bundle");
    NSArray<NSString*>* const localizations = bundle.localizations;
    appLocalization =
      [[NSBundle preferredLocalizationsFromArray:localizations
                                  forPreferences:NSBundle.mainBundle.preferredLocalizations]
        firstObject] ?: @"en";
    systemLocalization =
      [[NSBundle preferredLocalizationsFromArray:localizations
                                  forPreferences:NSLocale.preferredLanguages]
        firstObject] ?: @"en";
    localizedStrings_app = [[NSDictionary alloc] initWithContentsOfFile:
                             [bundle pathForResource:@"Localizable" ofType:@"strings"
                                         inDirectory:nil forLocalization:appLocalization]];
    localizedStrings_system = [[NSDictionary alloc] initWithContentsOfFile:
                                [bundle pathForResource:@"Localizable" ofType:@"strings"
                                            inDirectory:nil forLocalization:systemLocalization]];
    STU_CHECK_MSG(localizedStrings_app && localizedStrings_system,
                  "Failed to load STULabelResources strings dictionary");
  });
}

NSString* localizationLanguage() { return appLocalization; }

NSString* systemLocalizationLanguage() { return systemLocalization; }

NSString* localized(NSString* key) {
  initializeIfNecessary();
  NSString* const value = [localizedStrings_app objectForKey:key];
  STU_DEBUG_ASSERT(value != nil);
  return value ?: key;
}

NSString* localizedForSystemLocale(NSString* key) {
  initializeIfNecessary();
  NSString* const value = [localizedStrings_system objectForKey:key];
  STU_DEBUG_ASSERT(value != nil);
  return value ?: key;
}

}
