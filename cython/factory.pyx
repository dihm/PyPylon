from cython.operator cimport dereference as deref, preincrement as inc
from libcpp cimport bool
from libcpp.string cimport string

cimport numpy as np
import numpy as np

from pylon_def cimport *

cdef extern from "pylon/PylonIncludes.h" namespace 'Pylon':

    cpdef enum EGrabStrategy:
        GrabStrategy_OneByOne,
        GrabStrategy_LatestImageOnly,
        GrabStrategy_LatestImages,
        GrabStrategy_UpcomingImage

cdef class DeviceInfo:
    cdef:
        CDeviceInfo dev_info

    @staticmethod
    cdef create(CDeviceInfo dev_info):
        obj = DeviceInfo()
        obj.dev_info = dev_info
        return obj

    property serial_number:
        def __get__(self):
            return (<string>(self.dev_info.GetSerialNumber())).decode('ascii')

    property model_name:
        def __get__(self):
            return (<string>(self.dev_info.GetModelName())).decode('ascii')

    property user_defined_name:
        def __get__(self):
            return (<string>(self.dev_info.GetUserDefinedName())).decode('ascii')

    property device_version:
        def __get__(self):
            return (<string>(self.dev_info.GetDeviceVersion())).decode('ascii')

    property friendly_name:
        def __get__(self):
            return (<string>(self.dev_info.GetFriendlyName())).decode('ascii')

    property vendor_name:
        def __get__(self):
            return (<string>(self.dev_info.GetVendorName())).decode('ascii')

    property device_class:
        def __get__(self):
            return (<string>(self.dev_info.GetDeviceClass())).decode('ascii')

    def __repr__(self):
        return '<DeviceInfo {1}>'.format(self.serial_number, self.friendly_name)


cdef class CommandNodeProxy:
    cdef:
        ICommand* command

    @staticmethod
    cdef create(ICommand* command):
        obj = CommandNodeProxy()
        obj.command = command
        return obj

    def execute(self):
        self.command.Execute()

    def is_done(self):
        return self.command.IsDone()


cdef class NodeMap:
    cdef:
        INodeMap* map

    @staticmethod
    cdef create(INodeMap* map):
        obj = NodeMap()
        obj.map = map
        return obj

    def get_description(self, basestring key):
        cdef bytes btes_name = key.encode()
        cdef INode* node = self.map.GetNode(gcstring(btes_name))

        if node == NULL:
            raise KeyError('Key does not exist')

        return (<string>(node.GetDescription())).decode()


    def get_display_name(self, basestring key):
        cdef bytes btes_name = key.encode()
        cdef INode* node = self.map.GetNode(gcstring(btes_name))

        if node == NULL:
            raise KeyError('Key does not exist')

        return (<string>(node.GetDisplayName())).decode()


    def __getitem__(self, basestring key):
        cdef bytes btes_name = key.encode()
        cdef INode* node = self.map.GetNode(gcstring(btes_name))

        if node == NULL:
            raise KeyError('Key does not exist')

        # TODO: Would be nice to figure out how to do enums.

        cdef EInterfaceType interface_type = node.GetPrincipalInterfaceType()

        if interface_type == intfICommand:
           return CommandNodeProxy.create(dynamic_cast_icommand_ptr(node))


        if not node_is_readable(node):
            raise IOError('Key is not readable')


        if interface_type == intfIBoolean:
            return dynamic_cast_iboolean_ptr(node).GetValue()

        if interface_type == intfIInteger:
            return dynamic_cast_iinteger_ptr(node).GetValue()

        if interface_type == intfIFloat:
            return dynamic_cast_ifloat_ptr(node).GetValue()

        # Can generally always access a setting by string
        cdef IValue* string_value = dynamic_cast_ivalue_ptr(node)
        if string_value == NULL:
            raise RuntimeError('Can not get key %s as string' % key)

        return (<string>(string_value.ToString())).decode()


    def __setitem__(self, str key, value):
        cdef bytes bytes_name = key.encode()
        cdef INode* node = self.map.GetNode(gcstring(bytes_name))

        if node == NULL:
            raise KeyError('Key does not exist')

        if not node_is_writable(node):
            raise IOError('Key is not writable')

        # TODO: Would be nice to figure out how to do enums.

        cdef EInterfaceType interface_type = node.GetPrincipalInterfaceType()

        if interface_type == intfICommand:
           raise IOError('Command properties do not support assignment')

        if interface_type == intfIBoolean:
            dynamic_cast_iboolean_ptr(node).SetValue(value)
            return

        cdef IInteger* integer_value
        if interface_type == intfIInteger:
            integer_value = dynamic_cast_iinteger_ptr(node)
            if value < integer_value.GetMin() or value > integer_value.GetMax():
                raise ValueError('Parameter value for {} not inside valid range [{}, {}], was {}'.format(
                    key, integer_value.GetMin(), integer_value.GetMax(), value))
            integer_value.SetValue(value)
            return

        cdef IFloat* float_value
        if interface_type == intfIFloat:
            float_value = dynamic_cast_ifloat_ptr(node)
            if value < float_value.GetMin() or value > float_value.GetMax():
                raise ValueError('Parameter value for {} not inside valid range [{}, {}], was {}'.format(
                    key, float_value.GetMin(), float_value.GetMax(), value))
            float_value.SetValue(value)
            return

        # Can generally always access a setting by string
        cdef IValue* string_value = dynamic_cast_ivalue_ptr(node)
        if string_value == NULL:
            raise RuntimeError('Can not set key %s by string' % key)

        cdef bytes bytes_value = str(value).encode()
        string_value.FromString(gcstring(bytes_value))


    def keys(self):
        node_keys = list()

        # Iterate through the discovered devices
        cdef NodeList_t nodes
        self.map.GetNodes(nodes)

        cdef NodeList_t.iterator it = nodes.begin()
        while it != nodes.end():
            if deref(it).IsFeature() and dynamic_cast_icategory_ptr(deref(it)) == NULL:
                name = (<string>(deref(it).GetName())).decode('ascii')
                node_keys.append(name)
            inc(it)

        return node_keys


cdef class Camera:
    cdef:
        CInstantCamera camera
        bool _chunking_enabled

    @staticmethod
    cdef create(IPylonDevice* device):
        obj = Camera()
        obj.camera.Attach(device)
        obj._chunking_enabled = False
        return obj

    property device_info:
        def __get__(self):
            dev_inf = DeviceInfo.create(self.camera.GetDeviceInfo())
            return dev_inf

    property opened:
        def __get__(self):
            return self.camera.IsOpen()
        def __set__(self, opened):
            if self.opened and not opened:
                self.camera.Close()
            elif not self.opened and opened:
                self.camera.Open()

    property is_grabbing:
        def __get__(self):
            return self.camera.IsGrabbing()

    def open(self):
        self.camera.Open()

    def close(self):
        self.stop_grabbing()
        self.camera.Close()

    def stop_grabbing(self):
        if self.camera.IsGrabbing():
            self.camera.StopGrabbing()

    def __del__(self):
        self.close()
        self.camera.DetachDevice()

    def __repr__(self):
        return '<Camera {0} open={1}>'.format(self.device_info.friendly_name, self.opened)


    def enable_image_data_chunk(self, chunk_key):
        """ NOTE: "ChunkSelector" property is of type enum in underlying Pylon C++ interface, however haven't got enum support in pypylon
            wrapper NodeMap so use string equivelent representation <chunk_key> instead.  Valid values for <chunk_key> match the ChunkSelectorEnums
            value names in "include/pylon/gige/_BaslerGigECameraParams.h" with the "ChunkSelector_" prefix chipped off."""

        self._chunking_enabled = True
        dynamic_cast_iboolean_ptr(self.camera.GetNodeMap().GetNode(gcstring("ChunkModeActive"))).SetValue(True)

        dynamic_cast_ivalue_ptr(self.camera.GetNodeMap().GetNode(gcstring("ChunkSelector"))).FromString(gcstring(str(chunk_key).encode()))
        dynamic_cast_iboolean_ptr(self.camera.GetNodeMap().GetNode(gcstring("ChunkEnable"))).SetValue(True)


    def disable_image_data_chunk(self, chunk_key):

        dynamic_cast_ivalue_ptr(self.camera.GetNodeMap().GetNode(gcstring("ChunkSelector"))).FromString(gcstring(str(chunk_key).encode()))
        dynamic_cast_iboolean_ptr(self.camera.GetNodeMap().GetNode(gcstring("ChunkEnable"))).SetValue(False)


    def _grab_images(self, bool chunked, int nr_images, EGrabStrategy grab_strategy, unsigned int timeout):

        if not self.opened:
            raise RuntimeError('Camera not opened')

        cdef CGrabResultPtr ptr_grab_result
        cdef IImage* img

        cdef str image_format = str(self.properties['PixelFormat'])
        cdef str bits_per_pixel_prop = str(self.properties['PixelSize'])
        assert bits_per_pixel_prop.startswith('Bpp'), 'PixelSize property should start with "Bpp"'
        assert image_format.startswith('Mono'), 'Only mono images allowed at this point'
        assert not image_format.endswith('p'), 'Packed data not supported at this point'

        try:
            if nr_images < 1:
                self.camera.StartGrabbing(grab_strategy)
            else:
                self.camera.StartGrabbing(nr_images, grab_strategy)

            while self.camera.IsGrabbing():

                with nogil:
                    # Blocking call into native Pylon C++ SDK code, release GIL so other python threads can run
                    self.camera.RetrieveResult(timeout, ptr_grab_result)

                if not ACCESS_CGrabResultPtr_GrabSucceeded(ptr_grab_result):
                    error_desc = (<string>(ACCESS_CGrabResultPtr_GetErrorDescription(ptr_grab_result))).decode()
                    raise RuntimeError(error_desc)

                # Type conversion to IImage appears to work happily regardless of whether <ptr_grab_result> payload
                # type is PayloadType_ChunkData or PayloadType_Image
                img = &(<IImage&>ptr_grab_result)
                if not img.IsValid():
                    raise RuntimeError('Graped IImage is not valid.')

                if img.GetImageSize() % img.GetHeight():
                    print('This image buffer is wired. Probably you will see an error soonish.')
                    print('\tBytes:', img.GetImageSize())
                    print('\tHeight:', img.GetHeight())
                    print('\tWidth:', img.GetWidth())
                    print('\tGetPaddingX:', img.GetPaddingX())

                assert not img.GetPaddingX(), 'Image padding not supported.'
                # TODO: Check GetOrientation to fix oritentation of image if required.

                img_data = np.frombuffer((<char*>img.GetBuffer())[:img.GetImageSize()], dtype='uint'+bits_per_pixel_prop[3:])

                # TODO: How to handle multi-byte data here?
                img_data = img_data.reshape((img.GetHeight(), -1))
                # img_data = img_data[:img.GetHeight(), :img.GetWidth()]

                if (chunked):
                    # Client is requesting images to be returned as tuple of image and chunk data node map (dictionary-ish)
                    #
                    # Valid dictionary keys match the <chunk_key> values fed into enable_image_data_chunk() with a "Chunk"
                    # prefix

                    image_chunk_data = None

                    if self._chunking_enabled:

                        assert ACCESS_CGrabResultPtr_GetPayloadType(ptr_grab_result) == PayloadType_ChunkData

                        # NOTE: <image_chunk_data> refers to its underlying <ptr_grab_result> data structure via a normal pointer
                        # (rather than a reference counting smart pointer) and therefore does nothing to ensure that its
                        # lifetime is extended appropriately, however it is paired with <img_data> which does seem to have
                        # some form of smart reference back to the source <ptr_grab_result>.
                        image_chunk_data = NodeMap.create(&(ACCESS_CGrabResultPtr_GetChunkDataNodeMap(ptr_grab_result)))

                    yield (img_data, image_chunk_data)

                else:

                    yield img_data

        except:
            self.stop_grabbing()
            raise

    def grab_images(self, int nr_images = -1, EGrabStrategy grab_strategy=GrabStrategy_OneByOne, unsigned int timeout=5000):

        return self._grab_images(False, nr_images, grab_strategy, timeout)


    def grab_chunked_images(self, int nr_images = -1, EGrabStrategy grab_strategy=GrabStrategy_OneByOne, unsigned int timeout=5000):

        return self._grab_images(True, nr_images, grab_strategy, timeout)


    def grab_image(self, EGrabStrategy grab_strategy=GrabStrategy_OneByOne, unsigned int timeout=5000):
        return next(self.grab_images(False, 1, grab_strategy, timeout))


    def grab_chunked_image(self, EGrabStrategy grab_strategy=GrabStrategy_OneByOne, unsigned int timeout=5000):
        return next(self.grab_images(True, 1, grab_strategy, timeout))


    property properties:
        def __get__(self):
            return NodeMap.create(&self.camera.GetNodeMap())

    # Configuration properties associated with various grab strategies
    property max_num_buffer:
        def __get__(self):
            return self.camera.MaxNumBuffer.GetValue()
        def __set__(self, value):
            self.camera.MaxNumBuffer.SetValue(value)

    property max_num_queued_buffer:
        def __get__(self):
            return self.camera.MaxNumQueuedBuffer.GetValue()
        def __set__(self, value):
            self.camera.MaxNumQueuedBuffer.SetValue(value)

    property output_queue_size:
        def __get__(self):
            return self.camera.OutputQueueSize.GetValue()
        def __set__(self, value):
            self.camera.OutputQueueSize.SetValue(value)


cdef class Factory:
    def __cinit__(self):
        PylonInitialize()

    def __dealloc__(self):
        PylonTerminate()

    def find_devices(self):
        cdef CTlFactory* tl_factory = &GetInstance()
        cdef DeviceInfoList_t devices

        cdef int nr_devices = tl_factory.EnumerateDevices(devices)

        found_devices = list()

        # Iterate through the discovered devices
        cdef DeviceInfoList_t.iterator it = devices.begin()
        while it != devices.end():
            found_devices.append(DeviceInfo.create(deref(it)))
            inc(it)

        return found_devices

    def create_device(self, DeviceInfo dev_info):
        cdef CTlFactory* tl_factory = &GetInstance()
        return Camera.create(tl_factory.CreateDevice(dev_info.dev_info))
