// Copyright 2018 Stephan Tolksdorf

#include "TestValue.hpp"

STU_DISABLE_CLANG_WARNING("-Wglobal-constructors")
STU_DISABLE_CLANG_WARNING("-Wexit-time-destructors")
std::unordered_set<const TestValueB*> TestValueB::addresses;
std::unordered_set<const TestValue*> TestValue::addresses;
STU_REENABLE_CLANG_WARNING
STU_REENABLE_CLANG_WARNING

