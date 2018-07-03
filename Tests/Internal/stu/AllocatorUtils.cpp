// Copyright 2018 Stephan Tolksdorf

#include "AllocatorUtils.hpp"

STU_DISABLE_CLANG_WARNING("-Wexit-time-destructors")

MoveOnlyAllocatorRef::Allocator MoveOnlyAllocatorRef::Allocator::instance{};

STU_REENABLE_CLANG_WARNING

