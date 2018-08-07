# coding: utf8

# Copyright 2017–2018 Stephan Tolksdorf

import lldb

maxArrayElementCount = 1024

class ArrayRef_ChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj
    self.valueType = self.valobj.GetType().GetTemplateArgumentType(0)
    self.valueTypeSize = self.valueType.GetByteSize()
    self.update()

  def num_children(self):
    return self.count + 2 if self.count <= maxArrayElementCount else 2

  def get_child_index(self, name):
    if name == 'begin_':
      return 0
    if name == 'count_':
      return 1
    if name.startswith('['):
      return 2 + int(name[1:-1])
    else:
      return -1

  def get_child_at_index(self, index):
    if 0 <= index - 2 < self.count:
      index = index - 2
      offset = index * self.valueTypeSize
      child = self.beginValue.CreateChildAtOffset('[' + str(index) + ']', offset, self.valueType)
      return child
    elif index == 0:
      return self.beginValue
    elif index == 1:
      return self.countValue
    else:
      return None

  def update(self):
    self.beginValue = self.valobj.GetChildMemberWithName('begin_')
    self.countValue = self.valobj.GetChildMemberWithName('count_')
    self.count = self.countValue.GetValueAsUnsigned(0)

  def has_children(self):
    return True

# Also used as the SummaryFormatter for Vectors.
def ArrayRef_SummaryFormatter(valobj, dict):
  count = valobj.GetChildMemberWithName('count_').GetValueAsUnsigned()
  return '{count = %d}' % (count)

def Array_SummaryFormatter(valobj, dict):
  isFixed = valobj.GetType().GetTemplateArgumentType(1).GetName() == "stu::Fixed"
  if isFixed:
    count = valobj.GetChildMemberWithName('array').GetNumChildren()
  else:
    count = valobj.GetChildMemberWithName('count_').GetValueAsUnsigned()
  return '{count = %d}' % (count)

class Array_ChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj
    self.valueType = self.valobj.GetType().GetTemplateArgumentType(0)
    self.valueTypeSize = self.valueType.GetByteSize()
    self.isFixed = self.valobj.GetType().GetTemplateArgumentType(1).GetName() == "stu::Fixed"
    self.memberCount = 1 if self.isFixed else 2
    self.update()
    if self.isFixed and self.count == 0:
      self.memberCount = 0

  def num_children(self):
    return self.memberCount + (self.count if self.count <= maxArrayElementCount else 0)

  def get_child_index(self, name):
    if name == 'begin_' or name == 'array':
      return 0
    if name == 'count_':
      return 1
    if name.startswith('['):
      return self.memberCount + int(name[1:-1])
    else:
      return -1

  def get_child_at_index(self, index):
    if self.isFixed and index == 0:
      return self.fixedArray
    if 0 <= index - self.memberCount < self.count:
      index = index - self.memberCount
      if self.isFixed:
        return self.fixedArray.GetChildAtIndex(index)
      else:
        offset = index * self.valueTypeSize
        child = self.beginValue.CreateChildAtOffset('[' + str(index) + ']', offset, self.valueType)
        return child
    elif index == 0:
      return self.fixedArray if self.isFixed else self.beginValue
    elif index == 1:
      return self.countValue
    else:
      return None

  def update(self):
    if self.isFixed:
      self.fixedArray = self.valobj.GetChildMemberWithName('array')
      self.count = self.fixedArray.GetNumChildren()
    else:
      self.beginValue = self.valobj.GetChildMemberWithName('begin_')
      self.countValue = self.valobj.GetChildMemberWithName('count_')
      self.count = self.countValue.GetValueAsUnsigned(0)

  def has_children(self):
    return not (self.isFixed and self.count == 0)



class Vector_ChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj;
    self.valueType = self.valobj.GetType().GetTemplateArgumentType(0)
    self.valuePointerType = self.valueType.GetPointerType()
    self.valueTypeSize = self.valueType.GetByteSize()
    self.update()

  def num_children(self):
    return self.count + 3 if self.count <= maxArrayElementCount else 2

  def get_child_index(self, name):
    if name == 'begin_':
      return 0
    if name == 'count_':
      return 1
    elif name == 'capacity_':
      return 2
    if name.startswith('['):
      return 3 + int(name[1:-1])
    else:
      return -1

  def get_child_at_index(self, index):
    if 0 <= index - 3 < self.count:
      index = index - 3
      offset = index * self.valueTypeSize
      child = self.beginValue.CreateChildAtOffset('[' + str(index) + ']', offset, self.valueType)
      return child
    elif index == 0:
      return self.beginValue
    elif index == 1:
      return self.countValue
    elif index == 2:
      return self.capacityValue
    else:
      return None

  def update(self):
    self.beginValue = self.valobj.GetChildMemberWithName('begin_').Cast(self.valuePointerType)
    self.countValue = self.valobj.GetChildMemberWithName('count_')
    self.capacityValue = self.valobj.GetChildMemberWithName('capacity_')
    self.count = self.countValue.GetValueAsUnsigned(0)
    self.capacity = self.capacityValue.GetValueAsUnsigned(0)

  def has_children(self):
    return True

def None_SummaryFormatter(valobj, dict):
  return 'none'

class None_ChildrenProvider:
  def __init__(self, valobj, dict):
    return
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

cachedNoneValue = None
def getNoneValue(valobj):
  global cachedNoneValue
  if cachedNoneValue is None:
    value = valobj.target.FindFirstGlobalVariable('stu::none')
    cachedNoneValue = value.CreateValueFromData(None, value.GetData(), value.GetType())
  return cachedNoneValue

class Optional_ChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj
    try:
      self.hasHasValue = self.valobj.GetChildMemberWithName('hasValue_').IsValid()
    except:
      self.hasHasValue = False
    try:
      child = self.valobj.GetChildAtIndex(0).GetChildAtIndex(0).GetChildAtIndex(0)
      self.hasValue = child.GetValueForExpressionPath('.value_').IsValid()
      if self.hasValue:
        self.hasValueDepth = 3
      else:
        self.hasValue = child.GetChildAtIndex(0).GetValueForExpressionPath('.value_').IsValid()
        if self.hasValue:
          self.hasValueDepth = 4
    except:
      self.hasValue = False
    try:
      self.hasPointer = self.valobj.GetChildMemberWithName('pointer_').IsValid()
    except:
      self.hasPointer = False
    self.update()

  def num_children(self):
    return 1

  def get_child_index(self, name):
    return -1

  def get_child_at_index(self, index):
    if index == 0:
      if self.isNone:
        return getNoneValue(self.valobj)
      if self.hasValue:
        child = self.valobj
        for i in range(0, self.hasValueDepth):
          child = child.GetChildAtIndex(0)
        value = child.GetValueForExpressionPath('.value_')
        return self.valobj.CreateValueFromData(None, value.GetData(), value.GetType())
      if self.hasPointer:
        pointer = self.valobj.GetChildMemberWithName('pointer_')
        return self.valobj.CreateValueFromData(
                 None, pointer.GetData(), pointer.GetType().GetPointeeType().GetReferenceType())
      return self.valobj.GetChildAtIndex(0)
    return None

  def update(self):
    if self.hasHasValue:
      self.isNone = not self.valobj.GetChildMemberWithName('hasValue_').GetValueAsUnsigned(0)
    elif self.hasPointer:
      self.isNone = self.valobj.GetChildMemberWithName('pointer_').GetValueAsUnsigned(0) == 0
    else:
      self.isNone = False

  def has_children(self):
    return True

def Optional_SummaryFormatter(valobj, dict):
  value = valobj.GetChildAtIndex(0)
  if value.GetType() == getNoneValue(valobj).GetType(): return 'none'
  value = value.GetValue()
  return '' if value is None else value

def SmartPtr_SummaryFormatter(valobj, dict):
  value = valobj.GetNonSyntheticValue().GetChildAtIndex(0)
  while True:
    if not value.IsValid(): return ""
    if value.GetType().IsPointerType(): break
    value = value.GetChildAtIndex(0)
  if not value.GetValueAsUnsigned(): return 'nullptr'
  return value.GetSummary() or value.GetValue()

class SmartPtr_ChildrenProvider:
  def __init__(self, valobj, dict):
    self.valobj = valobj
    self.derefName = "*" + valobj.GetName()
    self.update()

  def num_children(self):
    if self.isNull:
      return 0
    return self.pointer.GetNumChildren()

  def get_child_index(self, name):
    if self.isNull:
      return -1
    elif name == self.derefName:
      return 0
    else:
      return self.pointer.GetIndexOfChildWithName(name)

  def get_child_at_index(self, index):
    if self.isNull:
      return None
    c = self.pointer.GetChildAtIndex(index)
    if c is not None and index == 0:
      name = c.GetName()
      if name is None or name.startswith("*"):
        return self.valobj.CreateValueFromData(self.derefName, c.GetData(), c.GetType())
    return c

  def update(self):
    self.pointer = self.valobj.GetChildAtIndex(0)
    while True:
      assert(self.pointer.IsValid())
      if self.pointer.GetType().IsPointerType(): break
      self.pointer = self.pointer.GetChildAtIndex(0)
    self.isNull = self.pointer.GetValueAsUnsigned() == 0

  def has_children(self):
    return not self.isNull

def Pair_SummaryFormatter(valobj, dict):
  first = valobj.GetChildAtIndex(0)
  firstValue = first.GetValue()
  if firstValue is None:
    firstValue = first.GetSummary()
  second = valobj.GetChildAtIndex(1)
  secondValue = second.GetValue()
  if secondValue is None:
    secondValue = second.GetSummary()
  if firstValue is None or secondValue is None:
    return ""
  return '{%s, %s}' % (firstValue, secondValue)

def PairWithNamedFields_SummaryFormatter(valobj, dict):
  first = valobj.GetChildAtIndex(0)
  firstValue = first.GetValue()
  if firstValue is None:
    firstValue = first.GetSummary()
  second = valobj.GetChildAtIndex(1)
  secondValue = second.GetValue()
  if secondValue is None:
    secondValue = second.GetSummary()
  if firstValue is None or secondValue is None:
    return ""
  return '{%s = %s, %s = %s}' % (first.GetName(), firstValue, second.GetName(), secondValue)

def Range_SummaryFormatter(valobj, dict):
  start = valobj.GetChildAtIndex(0)
  startValue = start.GetValue()
  if startValue is None:
    startValue = start.GetSummary()
  end = valobj.GetChildAtIndex(1)
  endValue = end.GetValue()
  if endValue is None:
    endValue = end.GetSummary()
  if startValue is None or endValue is None:
    return ""
  return '[%s, %s)' % (startValue, endValue)

def __lldb_init_module(dbg, dict):
  dbg.HandleCommand('type category enable stu')

  dbg.HandleCommand(
    'type summary add -w stu --summary-string "${var%u}"'
    ' stu::UInt8 stu::Byte ')

  dbg.HandleCommand(
    'type summary add -w stu --summary-string "${var%i}"'
    ' stu::Int8')

  dbg.HandleCommand(
    'type synthetic add -w stu -l stu_lldb_formatters.ArrayRef_ChildrenProvider'
    ' -x "^stu::ArrayRef<"')
  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.ArrayRef_SummaryFormatter'
    ' -x "^stu::ArrayRef<"')

  dbg.HandleCommand(
    'type synthetic add -w stu -l stu_lldb_formatters.Array_ChildrenProvider'
    ' -x "^stu::Array<"')
  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.Array_SummaryFormatter'
    ' -x "^stu::Array<"')

  dbg.HandleCommand(
    'type synthetic add -w stu -l stu_lldb_formatters.Vector_ChildrenProvider'
    ' -x "^stu::Vector<"')
  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.ArrayRef_SummaryFormatter'
    ' -x "^stu::Vector<"')

  dbg.HandleCommand(
    'type synthetic add -w stu -l stu_lldb_formatters.None_ChildrenProvider'
    ' -x "stu::None"')

  dbg.HandleCommand('type summary add -w stu --summary-string "none" stu::None')

  dbg.HandleCommand(
    'type synthetic add -w stu -l stu_lldb_formatters.Optional_ChildrenProvider'
    ' -x "^stu::Optional<"')
  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.Optional_SummaryFormatter'
    ' -x "^stu::Optional<"')

  dbg.HandleCommand(
    'type synthetic add -w stu -l stu_lldb_formatters.SmartPtr_ChildrenProvider'
    ' -x "^stu::UniquePtr<" "^stu::Malloced<" "^stu::RC<"')
  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.SmartPtr_SummaryFormatter'
    ' -x "^stu::UniquePtr<" "^stu::Malloced<" "^stu::RC<"')

  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.Pair_SummaryFormatter'
    ' -x "^stu::Pair<"')

  dbg.HandleCommand(
    'type summary add -w stu -F stu_lldb_formatters.Range_SummaryFormatter'
    ' -x "^stu::Range<"')

  dbg.HandleCommand(
    'type summary add -w stu --summary-string "${var.value}"'
    ' -x "^stu::Parameter<" ')

  parameter_names = ['Count', 'Capacity', 'ShouldIncrementRefCount']

  dbg.HandleCommand('type summary add -w stu --summary-string "${var.value}" '
                     + " ".join(['stu::' + name for name in parameter_names]))


  

  
