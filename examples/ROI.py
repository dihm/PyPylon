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

# get max pixels in X,Y
maxX = cam.properties['WidthMax']
maxY = cam.properties['HeightMax']

offX = maxX//4
offY = maxY//4
width = maxX//2
height = maxY//2

# check is ROI is valid
if offX+width > maxX:
    print('X offset+width > {}'.format(maxX))
    raise
if offY+height > maxY:
    print('Y offset+width > {}'.format(maxY))
    raise

# order important to avoid out of bounds errors
currX = cam.properties['Width']
currY = cam.properties['Height']

if offX > maxX-currX:
    cam.properties['Width'] = width
    cam.properties['OffsetX'] = offX
else:
    cam.properties['OffsetX'] = offX
    cam.properties['Width'] = width

if offY > maxY-currY:
    cam.properties['Height'] = height
    cam.properties['OffsetY'] = offY
else:
    cam.properties['OffsetY'] = offY
    cam.properties['Height'] = height

# print acquisition parameters
print('Exposure time:',cam.properties['ExposureTime'],'us')
print('Payload size:',cam.properties['PayloadSize'], 'bytes')
print('Pixel Format:',cam.properties['PixelFormat'])
print('Pixel Size:',cam.properties['PixelSize'])


for image in cam.grab_images(1):
    plt.imshow(image)
    plt.show()
