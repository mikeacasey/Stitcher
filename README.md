# Stitcher
A simple manual image stitcher to make a composite image from partial images. No automated alignment or warping. Best used with images captured from a computer screen. Not so great when stitching images from a panning camera.

Uses lua 5.1,IUP,IM,CD works in Lua for windows (https://github.com/rjpcomputing/luaforwindows


![image](https://user-images.githubusercontent.com/2499176/163371924-fc8340b4-99f4-4ffe-a879-5cba7cc832c0.png)
						Image 0.
						
Image 0. shows a baseimage (solid) with a moveable image (semi-transparent) being dragged by the mouse to the rougly correct position before using the movement keys for fine positioning.

Starting from an initial base image, sequentially add and join images until the final composite image is complete.
There is always a base image and a moveable image. The moveable image can be over the base image (default) or under the base image.
The upper image (moveable or base) is partially transparent to aid alignment.

The mouse keys (Right hand mouse) have the following functions associated with them:

	Left click: Drag moveable image (or base image when unlocked) or canvas in window when not pointing at draggable image
	Right click: Set background colour to the pixel under the cursor of either moveable or base image
	Wheel rotate: Reduce/Increase transparency of upper image by 1 step
	Wheel click: Toggle which image is upper image and lower image

The keyboard keys (US-qwerty) to use are:

- qwedcxza: For 1 pixel Movement in the directions NW,N,NE,E,SE,S,SW,W (the movement keys)
- s:	(flash key) Hide the movable image on key down and it reappears on key up
- j:	Join the movable image to the base image
- bm:	Rotate clockwise/anticlockwise by X degrees (configurable)
- n:	Reset rotation to 0 degrees

How to use it:
1. Prepare a set of images with a usable amount of overlap and organised to work left to right and top to bottom
2. Select the first (base)image that could/should be in the top left hand corner of the final composite image. Set the background colour now, don't change it -ever
3. Load the next (movable) image (it will appear in the bottom left corner) and use the mouse to drag the movable image to roughly where it should be over the baseimage (the overlapping images will appear fuzzy)
4. Use the flash key, quickly press and release the s key, the eye will pick up two (apparent) movements.
5. The first movement is when the movable images disappears and the eye shifts focus from the features in the movable image to the same features in the baseimage.
6. The second movement occurs when the movable image reappears and the eye shifts focus back to the features on the movable image.
7. The better and closer the overlaps are aligned the more obvious the apparent movement.
8. Press the movement key in the SAME direction as the FIRST apparent movement. Keep on pressing the appropriate direction keys until there is no apparent movement (or you have overshot and the apparent movement is now in the opposite direction)
9. When there is no apparent movement the overlaps between the base and movable image are aligned and the images can be joined (the overlapping images will appear sharp)
10. Load the next image and repeat the process

Notes:
1. What is a usable amount of overlap? -- it depends on the detail in the images: a few tens of pixels for sat photos is good; more, for relatively featureless maps with solid colours
2. What do you mean by organised? -- For example: capture images left to right and top to bottom and number them 1-1, 1-2, 1-3, 2-1, 2-2, ... Join them in this order.
3. What if I have captured my images right to left and bottom to top? -- unlock and move the base image and/or keep on increasing the canvas size when you run out of (virtual) canvas. The initial virtual canvas is pretty big and can be extended (extending it doesn't use memory, it's virtual)
4. What if I choose the wrong next image? -- Choose next image again and the current movable image will be replaced.
5. Choose your background colour at the start and don't change it as it is saved into the base images. For example, if making a composite map of an island, sample the sea (right mouse key) of the first image and use that colour as the background colour.

Useful tools:
1. Use the alignment grid to align Lat&Long lines on a rotated map image
2. Use the rectangle around the base map to get the composite image roughly square.
3. Set the background using the first image you load and then don't change it after that  (assuming the first image has the right colour).
