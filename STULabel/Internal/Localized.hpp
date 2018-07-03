// Copyright 2018 Stephan Tolksdorf

#import "Common.hpp"

namespace stu_label {

NSString* localizationLanguage();

NSString* systemLocalizationLanguage();

NSString* localized(NSString* key);

NSString* localizedForSystemLocale(NSString* key);

}
