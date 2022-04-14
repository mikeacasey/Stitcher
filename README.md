# Stitcher
Stitch images together

Uses lua 5.1,IUP,IM,CD works in Lua for windows (https://github.com/rjpcomputing/luaforwindows)
![image](https://user-images.githubusercontent.com/2499176/163339381-e7759777-c799-4343-8f6d-c2533a02b7ad.png)


Starting from an initial base image, sequentially add and join images until the final composite image is complete.
There is always a base image and a moveable image. The moveable image can be over the base image (default) or under the base image.
The upper image (moveable or base) is partially transparent to aid alignment.

The mouse keys (Right hand mouse) have the following functions associated with them:

	Left click: Drag moveable image (or base image when unlocked) or canvas in window when not pointing at draggable image
	Right click: Set background colour to the pixel under the cursor of either moveable or base image
	Wheel rotate: Reduce/Increase transparency of upper image by 1 step
	Wheel click: Toggle which image is upper image and lower image

The keyboard keys to use are:

- qwedcxza: For 1 pixel Movement in the directions NE,N,NE,W,SE,S,SW,W (the movement keys)
- s:	(Flash) Hide the movable image on key down and it reappears on key up
- j:	Join the movable image to the base image
- bm:	Rotate clockwise/anticlockwise by X degrees (configurable)
- n:	Reset rotation to 0 degrees

How to use it:
1. Prepare a set of images with a usable amount of overlap and organised to work left to right and top to bottom
2. Select the first (base)image that could/should be in the top left hand corner of the final composite image
2.1 Set the background colour now, don't change it -ever
3. Load the next (movable) image and use the mouse to drag the movable image to roughly where it should be over the baseimage (the overlapping images will appear fuzzy)
4. Use the flash, quickly press and release the s key, the eye will pick up two (apparent) movements
4.1 The first movement is when the movable images disappears and the eye shifts focus from the features in the movable image to the same features in the baseimage,
4.2 The second movement occurs when the movable image reappears and the eye shifts focus back to the features on the movable image
4.3 The better and closer the overlaps are aligned the more obvious the apparent movement.
5. Press the movement key in the SAME direction as the FIRST apparent movement. Keep on pressing the appropriate direction keys until there is no apparent movement.
6. When there is no apparent movement the overlaps between the base and movable image are aligned and the images can be joined (the overlapping images will appear sharp)
7. Load the next image and repeat the process

Notes:
1. What is a usable amount of overlap? -- it depends on the detail in the images: a few tens of pixels for sat photos is good; more, for relatively featureless maps with solid colours
2. What do you mean by organised? -- For example: capture images left to right and top to bottom and number them 1-1, 1-2, 1-3, 2-1, 2-2, ...
2.1 What if I have captured my images right to left and bottom to top? -- unlock and move the base image and/or keep on increasing the canvas size when you run out of (virtual) canvas
3. What if I choose the wrong next image? -- Choose next image again and the current movable image will be replaced.
4. Choose your background colour at the start and don't change it as it is saved into the base images.
4.1 For example, if making a composite map of an island, sample the sea (right mouse key) of the first image and use that colour as the bachground colour.

Useful tools:
1. Use the alignment grid to align Lat&Long lines on a rotated map image
2. Use the rectangle around the base map to get the composite image roughly square.
3. Set the background using the first image you load and then don't change it after that  (assuming the first image has the right colour).
