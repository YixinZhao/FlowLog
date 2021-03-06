# Generated by the protocol buffer compiler.  DO NOT EDIT!

from google.protobuf import descriptor
from google.protobuf import message
from google.protobuf import reflection
from google.protobuf import descriptor_pb2
# @@protoc_insertion_point(imports)



DESCRIPTOR = descriptor.FileDescriptor(
  name='routers.proto',
  package='flowlog',
  serialized_pb='\n\rrouters.proto\x12\x07\x66lowlog\"0\n\x06Subnet\x12\x0c\n\x04\x61\x64\x64r\x18\x01 \x01(\t\x12\x0c\n\x04mask\x18\x02 \x01(\x05\x12\n\n\x02gw\x18\x03 \x01(\t\"%\n\x07Network\x12\x0c\n\x04\x61\x64\x64r\x18\x01 \x01(\t\x12\x0c\n\x04mask\x18\x02 \x01(\x05\"Q\n\x04Peer\x12\n\n\x02ip\x18\x01 \x01(\t\x12\x0c\n\x04mask\x18\x02 \x01(\x05\x12\x0b\n\x03mac\x18\x03 \x01(\t\x12\"\n\x08networks\x18\x04 \x03(\x0b\x32\x10.flowlog.Network\"\x9e\x01\n\x06Router\x12\x0c\n\x04name\x18\x01 \x01(\t\x12\x11\n\tself_dpid\x18\x02 \x01(\t\x12\x10\n\x08nat_dpid\x18\x03 \x01(\t\x12\x0f\n\x07tr_dpid\x18\x06 \x01(\t\x12\x10\n\x08\x61\x63l_dpid\x18\x07 \x01(\t\x12 \n\x07subnets\x18\x04 \x03(\x0b\x32\x0f.flowlog.Subnet\x12\x1c\n\x05peers\x18\x05 \x03(\x0b\x32\r.flowlog.Peer\"E\n\x07Routers\x12 \n\x07routers\x18\x01 \x03(\x0b\x32\x0f.flowlog.Router\x12\x18\n\x10subnet_base_dpid\x18\x02 \x01(\t')




_SUBNET = descriptor.Descriptor(
  name='Subnet',
  full_name='flowlog.Subnet',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  fields=[
    descriptor.FieldDescriptor(
      name='addr', full_name='flowlog.Subnet.addr', index=0,
      number=1, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='mask', full_name='flowlog.Subnet.mask', index=1,
      number=2, type=5, cpp_type=1, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='gw', full_name='flowlog.Subnet.gw', index=2,
      number=3, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  options=None,
  is_extendable=False,
  extension_ranges=[],
  serialized_start=26,
  serialized_end=74,
)


_NETWORK = descriptor.Descriptor(
  name='Network',
  full_name='flowlog.Network',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  fields=[
    descriptor.FieldDescriptor(
      name='addr', full_name='flowlog.Network.addr', index=0,
      number=1, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='mask', full_name='flowlog.Network.mask', index=1,
      number=2, type=5, cpp_type=1, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  options=None,
  is_extendable=False,
  extension_ranges=[],
  serialized_start=76,
  serialized_end=113,
)


_PEER = descriptor.Descriptor(
  name='Peer',
  full_name='flowlog.Peer',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  fields=[
    descriptor.FieldDescriptor(
      name='ip', full_name='flowlog.Peer.ip', index=0,
      number=1, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='mask', full_name='flowlog.Peer.mask', index=1,
      number=2, type=5, cpp_type=1, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='mac', full_name='flowlog.Peer.mac', index=2,
      number=3, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='networks', full_name='flowlog.Peer.networks', index=3,
      number=4, type=11, cpp_type=10, label=3,
      has_default_value=False, default_value=[],
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  options=None,
  is_extendable=False,
  extension_ranges=[],
  serialized_start=115,
  serialized_end=196,
)


_ROUTER = descriptor.Descriptor(
  name='Router',
  full_name='flowlog.Router',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  fields=[
    descriptor.FieldDescriptor(
      name='name', full_name='flowlog.Router.name', index=0,
      number=1, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='self_dpid', full_name='flowlog.Router.self_dpid', index=1,
      number=2, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='nat_dpid', full_name='flowlog.Router.nat_dpid', index=2,
      number=3, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='tr_dpid', full_name='flowlog.Router.tr_dpid', index=3,
      number=6, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='acl_dpid', full_name='flowlog.Router.acl_dpid', index=4,
      number=7, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='subnets', full_name='flowlog.Router.subnets', index=5,
      number=4, type=11, cpp_type=10, label=3,
      has_default_value=False, default_value=[],
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='peers', full_name='flowlog.Router.peers', index=6,
      number=5, type=11, cpp_type=10, label=3,
      has_default_value=False, default_value=[],
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  options=None,
  is_extendable=False,
  extension_ranges=[],
  serialized_start=199,
  serialized_end=357,
)


_ROUTERS = descriptor.Descriptor(
  name='Routers',
  full_name='flowlog.Routers',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  fields=[
    descriptor.FieldDescriptor(
      name='routers', full_name='flowlog.Routers.routers', index=0,
      number=1, type=11, cpp_type=10, label=3,
      has_default_value=False, default_value=[],
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
    descriptor.FieldDescriptor(
      name='subnet_base_dpid', full_name='flowlog.Routers.subnet_base_dpid', index=1,
      number=2, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=unicode("", "utf-8"),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      options=None),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  options=None,
  is_extendable=False,
  extension_ranges=[],
  serialized_start=359,
  serialized_end=428,
)

_PEER.fields_by_name['networks'].message_type = _NETWORK
_ROUTER.fields_by_name['subnets'].message_type = _SUBNET
_ROUTER.fields_by_name['peers'].message_type = _PEER
_ROUTERS.fields_by_name['routers'].message_type = _ROUTER
DESCRIPTOR.message_types_by_name['Subnet'] = _SUBNET
DESCRIPTOR.message_types_by_name['Network'] = _NETWORK
DESCRIPTOR.message_types_by_name['Peer'] = _PEER
DESCRIPTOR.message_types_by_name['Router'] = _ROUTER
DESCRIPTOR.message_types_by_name['Routers'] = _ROUTERS

class Subnet(message.Message):
  __metaclass__ = reflection.GeneratedProtocolMessageType
  DESCRIPTOR = _SUBNET
  
  # @@protoc_insertion_point(class_scope:flowlog.Subnet)

class Network(message.Message):
  __metaclass__ = reflection.GeneratedProtocolMessageType
  DESCRIPTOR = _NETWORK
  
  # @@protoc_insertion_point(class_scope:flowlog.Network)

class Peer(message.Message):
  __metaclass__ = reflection.GeneratedProtocolMessageType
  DESCRIPTOR = _PEER
  
  # @@protoc_insertion_point(class_scope:flowlog.Peer)

class Router(message.Message):
  __metaclass__ = reflection.GeneratedProtocolMessageType
  DESCRIPTOR = _ROUTER
  
  # @@protoc_insertion_point(class_scope:flowlog.Router)

class Routers(message.Message):
  __metaclass__ = reflection.GeneratedProtocolMessageType
  DESCRIPTOR = _ROUTERS
  
  # @@protoc_insertion_point(class_scope:flowlog.Routers)

# @@protoc_insertion_point(module_scope)
