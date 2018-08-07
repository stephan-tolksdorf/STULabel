# coding: utf8

# Copyright 2018 Stephan Tolksdorf

# Import this script from the lldb command line or from ~/.lldbinit with:
#
#  command script import {path-to-STULabel-source}/STULabel/stu_label_lldb_formatters.py

import lldb
import os

textFlagIndices = [
  ('hasLink',           0),
  ('hasBackground',     1),
  ('hasShadow',         2),
  ('hasUnderline',      3),
  ('hasStrikethrough',  4),
  ('hasStroke',         5),
  ('hasAttachment',     6),
  ('hasBaselineOffset', 7),
  ('mayNotBeGrayscale', 8),
  ('usesExtendedColor', 9),
  ('everyRunFlag',     10)
]

textFrameFlagIndices = textFlagIndices[:-1] + [
  ('isTruncated',            10),
  ('isScaled',               11),
  ('hasMaxTypographicWidth', 12)
]

textStyleInfos = [
  ('LinkInfo',           0),
  ('BackgroundInfo',     1),
  ('ShadowInfo',         2),
  ('UnderlineInfo',      3),
  ('StrikethroughInfo',  4),
  ('StrokeInfo',         5),
  ('AttachmentInfo',     6),
  ('BaselineOffsetInfo', 7),
]


class FlagsEnumChildrenProvider:
  def __init__(self, valobj, dict, underlyingType, indices):
    self.indices = indices
    self.valobj = valobj
    self.underlyingType = underlyingType
    self.update()

  def has_children(self):
    return len(self.children) != 0

  def num_children(self):
    return len(self.children)

  def get_child_index(self, name):
    return self.childrenNamesByIndex[name]

  def get_child_at_index(self, index):
    (name, bit) = self.children[index]
    data = lldb.SBData.CreateDataFromInt(bit)
    return self.valobj.CreateValueFromData(name, data, self.underlyingType)

  def update(self):
    value = self.valobj.GetValueAsUnsigned(0)
    self.children = []
    for name, index in self.indices:
      bit = value & (1 << index)
      if bit:
        self.children.append((name, bit))
    self.childIndicesByName = {name: i for (i, (name, _)) in enumerate(self.children)}

class TextFlags_ChildrenProvider(FlagsEnumChildrenProvider):
  def __init__(self, valobj, dict):
    FlagsEnumChildrenProvider.__init__(self, valobj, dict,
                                       valobj.GetType().GetBasicType(lldb.eBasicTypeUnsignedShort),
                                       textFlagIndices)

class TextFrameFlags_ChildrenProvider(FlagsEnumChildrenProvider):
  def __init__(self, valobj, dict):
    FlagsEnumChildrenProvider.__init__(self, valobj, dict,
                                       valobj.GetType().GetBasicType(lldb.eBasicTypeUnsignedShort),
                                       textFrameFlagIndices)

def FlagsEnumSummaryFormatter(valobj, dict):
  value = valobj.GetValueAsUnsigned()
  if value == 0:
    return "none"
  array = []
  for i in range(0, valobj.GetNumChildren()):
    array.append(valobj.GetChildAtIndex(i).GetName())
  return ", ".join(array)

class HashTableBucket_ChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj
    type = valobj.GetType()
    if type.IsReferenceType():
      type = type.GetDereferencedType()
    elif type.IsPointerType():
      type = type.GetPointeeType()
    self.hasHashCode = type.GetTemplateArgumentType(1).GetName() != "stu::NoType"
    # type.GetNumberOfTemplateArguments() and type.GetTemplateArgumentType(2) don't seem to
    # work properly for this variadic template type.
    self.hasValue = valobj.GetChildMemberWithName("value").IsValid()
    if self.hasValue:
      self.childCount = 3 if self.hasHashCode else 2
    else:
      self.childCount = 2 if self.hasHashCode else 1
    self.update()

  def num_children(self):
    return self.childCount

  def get_child_index(self, name):
    if name == self.key.GetName(): return 0
    if name == "hashCode" and self.hasHashCode: return 1
    if name == "value" and self.hasValue:
      return 2 if self.hasHashCode else 1
    return -1

  def get_child_at_index(self, index):
    if index == 0:
      return self.key
    elif index == 1:
      if self.hasHashCode:
        return self.hashCode
      elif self.hasValue:
        return self.value
    elif index == 2 and self.hasValue:
      return self.value
    return None

  def update(self):
    self.key = self.valobj.GetChildAtIndex(0).GetChildAtIndex(0).GetChildAtIndex(0)
    if self.hasHashCode:
      self.hashCode = self.valobj.GetChildAtIndex(0).GetChildAtIndex(1)
    if self.hasValue:
      self.value = self.valobj.GetChildAtIndex(1)

  def has_children(self):
    return True

def HashTableBucket_SummaryFormatter(valobj, dict):
  key = valobj.GetChildAtIndex(0)
  isKeyPlus1 = key.GetName() == "keyPlus1"
  if isKeyPlus1: 
    keyValue = key.GetValueAsUnsigned()
    if not keyValue:
      return "empty"
    keyValue -= 1
  else:
    keyValue = key.GetValue()
    if keyValue is None:
      keyValue = key.GetSummary()
      if keyValue is None:
        return ""
      if keyValue == "none" or keyValue == "nullptr":
        keyValue = 0
    if not keyValue:
      return "empty"
  value = valobj.GetChildMemberWithName("value")
  valueValue = None
  if value is not None and value.IsValid():
    valueValue = value.GetValue()
    if valueValue is None:
      valueValue = value.GetSummary()
  if valueValue is None:
    return "{key = %s}" % (keyValue)
  return "{key = %s, value = %s}" % (keyValue, valueValue)

class ValueWrapperChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj

  def num_children(self):
    return 0

  def get_child_index(self, name):
    return -1

  def get_child_at_index(self, index):
    return None

  def update(self):
    return True

  def has_children(self):
    return False

  def get_value(self):
    return self.valobj.GetChildAtIndex(0).GetValue()

def ctFontName(valobj):
  str = valobj.GetObjectDescription()
  if str is None:
    return ''

  def substring(property):
    i1 = str.find(property + ': ')
    if i1 < 0: return None
    i1 += len(property) + 2
    i2 = str.find(';', i1)
    if i2 < 0: i2 = len(str)
    return str[i1:i2]

  return "%s %s, weight: %s, style: %s" % (substring("font-family")[1:-1], substring("font-size"),
                                           substring("font-weight"), substring("font-style"))

def CTFont_SummaryFormatter(valobj, dict):
  type = valobj.GetType()
  if type.IsPointerType() or type.IsReferenceType():
    if valobj.GetValueAsUnsigned() == 0:
      return 'nullptr'
  return ctFontName(valobj)

def CTFontWrapper_SummaryFormatter(valobj, dict):
  return CTFont_SummaryFormatter(valobj.GetChildAtIndex(0), dict)

def cgFontName(valobj):
  str = valobj.GetObjectDescription()
  if str is not None:
    i1 = str.find('): ')
    if i1 < 0:
      return str
    str = str[i1 + 3:]
    i2 = str.find('>')
    if i2 >= 0:
      str = str[:i2]
  return str

def CGFontWrapper_SummaryFormatter(valobj, dict):
  return cgFontName(valobj.GetNonSyntheticValue().GetChildAtIndex(0))

cachedTypes = {}
def getType(valobj, name):
  global cachedTypes
  type = cachedTypes.get(name)
  if type:
    return type
  # There must be a better way to reliably get an SBType from a qualified type name...
  type = valobj.target.FindFirstType(name)
  if not type.IsValid():
    types = valobj.target.FindTypes(name)
    if types:
      type = types.GetTypeAtIndex(0)
      if not type.IsValid():
        type = valobj.CreateValueFromExpression(None, "(%s *)0" % (name)).GetType()
        if type.IsValid():
          type = type.GetPointeeType()
  assert type.IsValid(), "Could not find type '%s'" % (name)
  cachedTypes[name] = type
  return type

cachedTextStyleInfoOffsets = None
def getTextStyleInfoOffsets(valobj):
  global cachedTextStyleInfoOffsets
  if cachedTextStyleInfoOffsets is None:
    value = valobj.target.FindFirstGlobalVariable('stu_label::TextStyle::infoOffsets')
    assert(value.IsValid())
    array = []
    for i in range(0, value.GetNumChildren()):
      array.append(value.GetChildAtIndex(i).GetValueAsUnsigned())
    cachedTextStyleInfoOffsets = array
  return cachedTextStyleInfoOffsets

cachedTextStylesOverrideInfoOffset = None
def getTextStylesOverrideInfoOffset(valobj):
  global cachedTextStylesOverrideInfoOffset
  if cachedTextStylesOverrideInfoOffset is None:
    type = getType(valobj, 'stu_label::TextStyleOverride')
    assert(type.IsValid())
    styleOffset = 0
    infosOffset = 0
    for field in type.get_fields_array():
      if field.GetName() == "style_":
        styleOffset = field.GetOffsetInBytes()
      elif field.GetName() == "styleInfos_":
        infosOffset = field.GetOffsetInBytes()
    assert(styleOffset and infosOffset)
    cachedTextStylesOverrideInfoOffset = infosOffset - styleOffset
  return cachedTextStylesOverrideInfoOffset

def createPointerValueFromInt(valobj, name, pointerType, value):
  target = valobj.GetTarget()
  addressSize = target.GetAddressByteSize()
  if addressSize == 8:
    data = lldb.SBData.CreateDataFromUInt64Array(target.GetByteOrder(), 8, [value])
  else:
    data = lldb.SBData.CreateDataFromUInt32Array(target.GetByteOrder(), 4, [value])
  return target.CreateValueFromData(name, data, pointerType)

class TextStyle_ChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj
    type = valobj.GetType()
    self.isPointerOrReference = type.IsPointerType() or type.IsReferenceType()
    self.pointerSize = valobj.GetTarget().GetAddressByteSize()
    self.update()

  def num_children(self):
    if self.address == 0: return 0
    return 6 + len(self.optionalChildren)

  def get_child_index(self, name):
    if self.address == 0: return None
    if name == "stringIndex": return 0
    if name == "flags": return 1
    if name == "next": return 2
    if name == "previous": return 3
    if name == "fontIndex": return 4
    if name == "colorIndex": return 5
    return self.optionalChildrenIndices.get(name, -1)

  def get_child_at_index(self, index):
    if index < 0 or self.address == 0: return None
    if index == 0:
      return self.valobj.CreateValueFromData('stringIndex',
               lldb.SBData.CreateDataFromInt(self.stringIndex), getType(self.valobj, "stu::Int32"))
    if index == 1:
      return self.valobj.CreateValueFromData('flags',
               lldb.SBData.CreateDataFromInt(self.flags), getType(self.valobj,
                                                                  "stu_label::TextFlags"))
    if index == 2:
      p = 0 if self.offsetToNext == 0 else self.address + self.offsetToNext
      return createPointerValueFromInt(self.valobj, 'next',
                                       getType(self.valobj, "const stu_label::TextStyle *"), p)
    if index == 3:
      p = 0 if self.offsetFromPrevious == 0 else self.address - self.offsetFromPrevious
      return createPointerValueFromInt(self.valobj, 'previous',
                                       getType(self.valobj, "const stu_label::TextStyle *"), p)
    if index == 4:
      return self.fontIndexChild
    if index == 5:
      return self.colorIndexChild
    index -= 6
    if index < len(self.optionalChildren):
      c = self.optionalChildren[index]
      return c
    return None

  def update(self):
    if self.isPointerOrReference:
      self.address = self.valobj.GetValueAsUnsigned()
    else:
      self.address = self.valobj.GetLoadAddress()
    if self.address == 0: return

    size_flags = 10
    size_offsetFromPreviousDiv4 = 5
    size_offsetToNextDiv4 = 5
    size_small_stringIndex = 26
    size_small_font = 8
    size_small_color = 8
    size_big_stringIndex = 31

    index_isBig = 0;
    index_flags = 1;
    index_offsetFromPreviousDiv4 = index_flags + size_flags;
    index_isOverride = index_offsetFromPreviousDiv4 + size_offsetFromPreviousDiv4;
    index_offsetToNextDiv4 = index_isOverride + 1;
    index_stringIndex = index_offsetToNextDiv4 + size_offsetToNextDiv4
    index_small_font = index_stringIndex + size_small_stringIndex
    index_small_color = index_small_font + size_small_font

    bits = self.valobj.GetChildAtIndex(0).GetValueAsUnsigned()
    isBig = (bits & (1 << index_isBig)) != 0
    self.isBig = isBig
    self.isOverrideStyle = (bits & (1 << index_isOverride)) != 0
    self.flags = (bits >> index_flags) & ((1 << size_flags) - 1)
    size_stringIndex = size_big_stringIndex if isBig else size_small_stringIndex
    self.stringIndex = (bits >> index_stringIndex) & ((1 << size_stringIndex) - 1)
    self.offsetFromPrevious = 4*((bits >> index_offsetFromPreviousDiv4)
                                 & ((1 << size_offsetFromPreviousDiv4) - 1))
    self.offsetToNext = 4*(bits >> index_offsetToNextDiv4) & ((1 << size_offsetToNextDiv4) - 1)

    assert(size_small_font == 8 and size_small_color == 8)
    assert(index_small_font + size_small_font == index_small_color)
    assert(index_small_color + size_small_color == 64)

    fontIndex_offset = 8 if isBig else index_small_font/8
    colorIndex_offset = 10 if isBig else index_small_color/8

    fontIndexType = getType(self.valobj, "stu::UInt16" if isBig else "stu::UInt8")
    self.fontIndexChild = self.valobj.CreateChildAtOffset('fontIndex',
                                                          fontIndex_offset, fontIndexType)
    self.colorIndexChild = self.valobj.CreateChildAtOffset('colorIndex',
                                                           colorIndex_offset, fontIndexType)

    self.optionalChildren = []
    self.optionalChildrenIndices = {}
    if self.flags:
      offsets = getTextStyleInfoOffsets(self.valobj)
      global textStyleInfos
      if self.isOverrideStyle:
        overrideInfoOffset = getTextStylesOverrideInfoOffset(self.valobj)
      for typeName, index in textStyleInfos:
        if self.flags & (1 << index):
          name = typeName[:1].lower() + typeName[1:]
          self.optionalChildrenIndices[name] = len(self.optionalChildren)
          if not self.isOverrideStyle:
            type = getType(self.valobj, "stu_label::TextStyle::" + typeName)
            offsetIndex = bits & ((1 << (index_flags + index)) - 1)
            offset = offsets[bits & ((1 << (index_flags + index)) - 1)]
            self.optionalChildren.append(self.valobj.CreateChildAtOffset(name, offset, type))
          else:
            type = getType(self.valobj, "const stu_label::TextStyle::" + typeName)
            offset = overrideInfoOffset + self.pointerSize*(index - 1)
            self.optionalChildren.append(self.valobj.CreateChildAtOffset(name, offset,
                                                                         type.GetPointerType()))

  def has_children(self):
    return self.address != 0

def TextStyle_SummaryFormatter(valobj, dict):
  stringIndex = valobj.GetChildMemberWithName("stringIndex").GetValueAsUnsigned()
  next = valobj.GetChildMemberWithName("next")
  nextStringIndex = 0
  if next.GetValueAsUnsigned():
    nextStringIndex = next.Dereference().GetChildMemberWithName("stringIndex").GetValueAsUnsigned()
  flags = valobj.GetChildMemberWithName("flags")
  flagsString = ' ' + flags.GetSummary() if flags.GetValueAsUnsigned() else ''
  if nextStringIndex <= stringIndex:
    return '%s%s' % (stringIndex, flagsString)
  return '[%s, %s)%s' % (stringIndex, nextStringIndex, flagsString)

def __lldb_init_module(dbg, dict):
  # Import the formatter for the stu submodule:
  source_dir = os.path.dirname(os.path.abspath(__file__))
  stu_formatters_path = os.path.join(source_dir, "Internal", "stu", "stu_lldb_formatters.py")
  dbg.HandleCommand('command script import "{}"'.format(stu_formatters_path))

  dbg.HandleCommand('type category enable stu_label')

  dbg.HandleCommand(
    'type synthetic add -w stu_label -l stu_label_lldb_formatters.TextFlags_ChildrenProvider'
    ' STUTextFlags "stu_label::TextFlags"')

  dbg.HandleCommand(
    'type synthetic add -w stu_label -l stu_label_lldb_formatters.TextFrameFlags_ChildrenProvider'
    ' "STUTextFrameFlags"')

  dbg.HandleCommand(
    'type summary add -w stu_label -F stu_label_lldb_formatters.FlagsEnumSummaryFormatter'
    ' STUTextFlags STUTextFrameFlags stu_label::TextFlags')

  valueWrapperNames = [
    'ColorIndex', 'CornerRadius', 'DrawShadow', 'FontIndex', 'UnderlineStyle', 'StrikethroughStyle',
    'IndexInOriginalString', 'IndexInTruncatedString', 'IndexInTruncationToken' 'IsLeftVertex',
    'IsRightToLeftLine', 'IsTopOfTextLine', 'IsTruncationTokenRange', 'IsUpperVertex', 'Hyphen',
    'MarkVerticalEdgesVisited', 'SeparateParagraphs',
    'ShouldExtendTextLinesToCommonHorizontalBounds', 'ShouldFillTextLineGaps', 'SkipIsolatedText',
    'StartAtEndOfLineString', 'TextFrameOriginY', 'TokenStringOffset',
    'TrailingWhitespaceStringLength', 'VertexLineIndex'
  ]

  dbg.HandleCommand('type summary add -w stu_label --summary-string "${var.value}" '
                     + ' '.join(['stu_label::' + name for name in valueWrapperNames]))

  dbg.HandleCommand('type synthetic add -l stu_label_lldb_formatters.ValueWrapperChildrenProvider '
                     + ' '.join(['stu_label::' + name for name in valueWrapperNames]))

  aggregateWrapperNames = ['RangeInOriginalString<', 'RangeInTruncatedString<', 'TextFrameOrigin']

  dbg.HandleCommand('type summary add -w stu_label --summary-string "${var.value}"'
                     + ' -x '  ' '.join(['^stu_label::' + name for name in aggregateWrapperNames]))

  dbg.HandleCommand(
    'type summary add -w stu_label -F stu_lldb_formatters.PairWithNamedFields_SummaryFormatter'
    ' -x "^stu_label::Point<" "^stu_label::Size<" "^stu_label::Rect<" "^stu_label::EdgeInsets<"')

  dbg.HandleCommand(
    'type synthetic add -w stu -l stu_lldb_formatters.Vector_ChildrenProvider'
    ' -x "^stu_label::TempVector<"')
  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.ArrayRef_SummaryFormatter'
    ' -x "^stu_label::TempVector<"')

  dbg.HandleCommand(
    'type synthetic add -w stu_label -l stu_label_lldb_formatters.ValueWrapperChildrenProvider'
    ' -x "^stu_label::HashCode<"')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "${var.value%x}"'
    ' -x "^stu_label::HashCode<"')

  dbg.HandleCommand(
    'type synthetic add -w stu_label -l stu_label_lldb_formatters.HashTableBucket_ChildrenProvider'
    ' -x "^stu_label::HashTableBucket<"')

  dbg.HandleCommand(
    'type summary add -w stu_label -F stu_label_lldb_formatters.HashTableBucket_SummaryFormatter'
    ' -x "^stu_label::HashTableBucket<"')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "\{count = ${var.count_}\}"'
    ' -x "^stu_label::HashTable<"')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "${var.attributedString}"'
    ' "stu_label::NSAttributedStringRef"')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "${var.string_}"'
    ' "stu_label::NSStringRef"')

  dbg.HandleCommand(
    'type summary add -w stu_label -F stu_label_lldb_formatters.CTFont_SummaryFormatter'
    ' "stu_label::CTFont"')

  dbg.HandleCommand(
    'type summary add -w stu_label -F stu_label_lldb_formatters.CTFontWrapper_SummaryFormatter'
    ' "stu_label::FontRef" "stu::RC<const __CTFont>"')

  dbg.HandleCommand(
    'type summary add -w stu_label -F stu_label_lldb_formatters.CGFontWrapper_SummaryFormatter'
    ' "stu::RC<CGFont>"')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "${var.cgFont}"'
    ' "stu_label::FontFaceGlyphBoundsCache::FontFace"')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "${var.fontFace}"'
    ' "stu_label::FontFaceGlyphBoundsCache::Pool"')

  dbg.HandleCommand(
    'type synthetic add -w stu_label -l stu_label_lldb_formatters.TextStyle_ChildrenProvider'
    ' "stu_label::TextStyle"')
  dbg.HandleCommand(
    'type summary add -w stu_label -F stu_label_lldb_formatters.TextStyle_SummaryFormatter'
    ' "stu_label::TextStyle"')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "${var.attribute%@}"'
    ' "stu_label::TextStyle::LinkInfo')

  dbg.HandleCommand(
    'type summary add -w stu_label --summary-string "${var.baselineOffset}"'
    ' "stu_label::TextStyle::BaselineOffsetInfo')


