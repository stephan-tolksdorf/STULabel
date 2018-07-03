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
  ('usesWideColor',     9)
]

textFrameFlagIndices = textFlagIndices + [
  ('isTruncated',            10),
  ('isScaled',               11),
  ('hasMaxTypographicWidth', 12)
]

class EnumChildrenProvider:
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

class TextFlags_ChildrenProvider(EnumChildrenProvider):
  def __init__(self, valobj, dict):
    EnumChildrenProvider.__init__(self, valobj, dict,
                                  valobj.GetType().GetBasicType(lldb.eBasicTypeUnsignedShort),
                                  textFlagIndices)

class TextFrameFlags_ChildrenProvider(EnumChildrenProvider):
  def __init__(self, valobj, dict):
    EnumChildrenProvider.__init__(self, valobj, dict,
                                  valobj.GetType().GetBasicType(lldb.eBasicTypeUnsignedShort),
                                  textFrameFlagIndices)

def __lldb_init_module(dbg, dict):
  # Import the formatter for the stu submodule:
  source_dir = os.path.dirname(os.path.abspath(__file__))
  stu_formatters_path = os.path.join(source_dir, "Internal", "stu", "stu_lldb_formatters.py")
  dbg.HandleCommand('command script import "{}"'.format(stu_formatters_path))

  dbg.HandleCommand('type synthetic add "STUTextFlags"'
                    ' --python-class stu_label_lldb_formatters.TextFlags_ChildrenProvider')

  dbg.HandleCommand('type synthetic add "stu_label::TextFlags"'
                    ' --python-class stu_label_lldb_formatters.TextFlags_ChildrenProvider')

  dbg.HandleCommand('type synthetic add "STUTextFrameFlags"'
                    ' --python-class stu_label_lldb_formatters.TextFrameFlags_ChildrenProvider')

  parameter_names = ['ColorIndex', 'FontIndex', 'UnderlineStyle', 'StrikethroughStyle',
                     'IndexInOriginalString', 'IndexInTruncatedString', 'IndexInTruncationToken',
                     'RangeInTruncatedString', 'RangeInTruncatedString', 'IndexInTruncationToken',
                     'IsTruncationTokenRange',
                     'TextFrameOrigin', 'TextFrameOriginY', 'SkipIsolatedText',
                     'StartAtEndOfLineString', 'IsRightToLeftLine', 'MinInitialOffset',
                     'Hyphen', 'TrailingWhitespaceStringLength', 'TokenStringOffset',
                     'SeparateParagraphs', 'DrawShadow',
                     'CornerRadius', 'ShouldFillTextLineGaps',
                     'ShouldExtendTextLinesToCommonHorizontalBounds',
                     'IsTopOfTextLine', 'MarkVerticalEdgesVisited', 'VertexLineIndex',
                     'IsUpperVertex', 'IsLeftVertex']

  dbg.HandleCommand('type summary add --summary-string "${var.value}" '
                     + " ".join(['stu_label::' + name for name in parameter_names]))
