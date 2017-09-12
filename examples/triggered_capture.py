from __future__ import absolute_import, print_function, division

import pypylon
import matplotlib.pyplot as plt
import numpy as np

print('Build against pylon library version:', pypylon.pylon_version.version)

available_cameras = pypylon.factory.find_devices()
print('Available cameras are', available_cameras)

# Grep the first one and create a camera for it
cam = pypylon.factory.create_device(available_cameras[-1])

# We can still get information of the camera back
print('Camera info of camera object:', cam.device_info)

# Open camera and grep some images
cam.open()

# set triggered mode on Line1 external hardware trigger
# trigger is for frame start
cam.properties['TriggerMode'] = 'On'
cam.properties['TriggerSource'] = 'Line1'
cam.properties['TriggerSelector'] = 'FrameStart'

# print acquisition parameters
print('Exposure time:',cam.properties['ExposureTime'],'us')
print('Payload size:',cam.properties['PayloadSize'], 'bytes')
print('Pixel Format:',cam.properties['PixelFormat'])
print('Pixel Size:',cam.properties['PixelSize'])

n_cap = 3

fig, ax_arr = plt.subplots(1,n_cap,sharey=True)
for i,image in enumerate(cam.grab_images(n_cap)):
    ax_arr[i].imshow(image)

plt.show()
