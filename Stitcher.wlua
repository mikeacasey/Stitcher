-- Stitcher.wlua
-- Written by Michael Casey 2012
-- Copyright Michael casey
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.


require"imlua"
require"cdlua"
require"cdluaim"
require"iuplua"
require"iupluacontrols"
require"iupluacd"
require"iupluaim"
require"imlua_process"



function concat_fts(t)
local s=""
	for i,j in pairs(t) do
		s= s .. "*." .. i .. ";"
	end
	return s:sub(1, s:len()-1)
end



function show_contents(t, indent)
	local lindent= indent or ""
	if type(t) == "table" then
		for i,j in pairs(t) do
			if type(j) == "table" then
				print(lindent .. i .. " ---[")
				show_contents(j, lindent .. "        ")
				print(lindent .. i .." ---]")
			elseif type(j) == "userdata" then
				print(lindent .. i .. " == userdata")
			else
				print(lindent .. i .. " == " .. j)
			end
		end
	else
		print("Type is " .. type(t))
	end
end


--show_contents(im)
--show_contents(cd)
--show_contents(iup)

-- coordinates are based on the virtual area v which is the base image + edge area
-- when need to be displayed they are converted to real IUP coordinates based on
-- the visible canvas coordinates, here kept in screen area s
local b={} -- base picture
local m={} -- moveable picture
local s={} -- screen coordinates
local v={x=0, y=0} -- virtual coordinates of the base image + edge, obviously x,y is 0,0 (virtual)


--Defaults
local default={} --
default.virtual_w= 10000 -- the smallest width if the first or subsequent images are smaller
default.virtual_h= 10000 -- the smallest height if the first or subsequent images are smaller
default.virtual_sx= 4000 -- where the first image should be placed
default.virtual_sy= 4000 -- where the first image should be placed, index from bottom
default.edge= 100 -- edge or border size, same for width and height
default.env_file= "Stitcher.ini"
default.env_name="saved_env"
default.bgcolour= cd.WHITE
default.lock_base= true
default.filetypes={png="PNG", tif="TIFF", jpg="JPEG", gif="GIF", bmp="BMP", pcx="PCX", ras="RAS", sgi="SGI", tga="TGA",pnm="PNM",raw="RAW",krn="KRN", avi="AVI",ecw="ECW", jp2="JP2", wmv="WMV", ico="ICO"}
default.filetype_filter=concat_fts(default.filetypes)
default.rotate_step= 0.25 -- rotation by each keypress in degrees
default.moveable_image_over= true
default.history= true -- join history on by default
default.alpha=175 -- default transparency (0-255)
default.alpha_step=10 --each click of the mouse wheel
default.min_alpha=10 --so that image is still visible
default.dir="" -- default working directory
default.tmpsuffix="png"
default.tmpname="tmp"
default.language="ENGLISH"
default.window_w= 500 -- initial width of viewing window
default.window_h= 500 -- initial height of viewing window
default.canvas_size= "500x500"
default.line_width= 1 -- line width for vertical and horizontal alignment lines
default.fgcolour= cd.RED -- line colour for vertical and horizontal alignment lines
default.virtual_step= 1000 -- initial increase step of virtual canvas
default.pastename="paste" -- name for saved pasted images
default.paste_save= true -- true, iup likes 1/0, whether pasted images should be saved automatically

--[[
IM Internal Predefined File Formats:

  TIFF - Tagged Image File Format
  JPEG - JPEG File Interchange Format
  PNG - Portable Network Graphic Format
  GIF - Graphics Interchange Format
  BMP - Windows Device Independent Bitmap
  RAS - Sun Raster File
  LED - IUP image in LED
  SGI - Silicon Graphics Image File Format
  PCX - ZSoft Picture
  TGA - Truevision Graphics Adapter File
  PNM - Netpbm Portable Image Map
  ICO - Windows Icon
  KRN - IM Kernel File Format
  AVI - Windows Audio-Video Interleaved RIFF
  ECW - ECW JPEG 2000
  JP2 - JPEG-2000 JP2 File Format
  RAW - RAW File
  WMV - Windows Media Video Format


--]]



function encode_colour(rgb)
	if rgb and rgb.r and rgb.g and rgb.b then
		return cd.EncodeColor(rgb.r, rgb.g, rgb.b)
	else
		return nil
	end
end


-- execute the initialisation file
saved_env= {}
local sea, seb= pcall(dofile,default.env_file)
if sea == false then
	local ser = iup.Alarm("Stitcher - Problem with " .. default.env_file, seb ,"Continue", "Quit")
	if ser == 2 then
		return 0
	end
end

-- Globals
local g={}

g.md= 0 -- global mouse drag 1= of the moveable image, 2= base image, 3= scroll
g.mdx= 0 -- global x of where the mouse drag started
g.mdy= 0 -- global y of where the mouse drag started
g.ix= 0 -- global x of image drag started
g.iy= 0 -- global y of image drag started
g.image_avail= false -- global true if movable image loaded and available to be moved
g.bgcolour=  encode_colour(saved_env.bgcolour) or default.bgcolour
g.lock_base= default.lock_base -- base image locked and cannot be moved or rotated
g.rotate= 0 -- current degree of rotation of the current movable image
g.rotate_step= saved_env.rotate_step or default.rotate_step -- rotate amount in degrees per keypress
g.base_rotate= 0 -- -- current degree of rotation of the base image
g.moveable_image_over= default.moveable_image_over -- whether the moveable image will be over or under the base image
g.history= saved_env.history or default.history -- join history on or off
g.joins_count= 0 -- number of joins made so far
g.max_joins_count= 0 -- the max join number when edit history is on
g.flash= false -- if the image is being flashed
g.alpha= saved_env.alpha or default.alpha -- value of alpha channel of the image that is over, can be either moveable or base image
g.alpha_step= saved_env.alpha_step or default.alpha_step -- change in alpha for each mouse wheel click
g.max_alpha=255 -- max value of alpha channel, fully opaque
g.min_alpha= saved_env.min_alpha or default.min_alpha -- min value of alpha channel (0 is invisible)
g.dir = saved_env.dir or default.dir  -- working directory
g.tmpname= saved_env.tmpname or default.tmpname -- temporary join file name
g.tmpsuffix= saved_env.tmpsuffix or default.tmpsuffix  -- temporary join file suffix
g.tmpdir= saved_env.tmpdir or default.dir  -- temporary file directory
g.language=  default.language -- only english and portugese are available so stick to english
g.line_on= false -- vertical and horizontal lines for alignment during rotation
g.line_width= saved_env.line_width or default.line_width -- line width
g.fgcolour=  encode_colour(saved_env.fgcolour) or default.fgcolour -- foreground colour, used for alignment lines and join text
g.rectangle=false -- show a rectangle around the baseimage
g.virtual_w= saved_env.virtual_w or default.virtual_w -- initial width of virtual canvas
g.virtual_h= saved_env.virtual_h or default.virtual_h -- initial height of virtual canvas
g.virtual_step= saved_env.virtual_step or default.virtual_step -- initial increase step of virtual canvas
g.window_w= saved_env.window_w or default.window_w -- initial width of viewing window
g.window_h= saved_env.window_h or default.window_h -- initial height of viewing window
g.canvas_size= g.window_w .."x".. g.window_h
g.canvas_h= g.window_h - 16 -- canvas size less scroll bars (approximate 16)
g.canvas_w= g.window_w - 16 -- canvas size less scroll bars (approximate 16)
g.virtual_sx= saved_env.virtual_sx or default.virtual_sx
g.virtual_sy= saved_env.virtual_sy or default.virtual_sy
g.edge= saved_env.edge or default.edge
g.paste_count= 0
g.pastename= saved_env.pastename or default.pastename
g.paste_save= saved_env.paste_save and default.paste_save -- and because they are boolean values and default is true


local iswindows = os.getenv('WINDIR') or (os.getenv('OS') or ''):match('[Ww]indows')
--print(os.getenv('WINDIR'), (os.getenv('OS') or ''):match('[Ww]indows'))

if iswindows then
	g.path_sep= [[\]]
	g.os_success= 0
	g.os_fail= 1
else
	g.path_sep= [[/]]
	g.os_success= 0
	g.os_fail= 256
end
g.iup_path_sep= [[/]]
--print(g.path_sep, g.iup_path_sep)



function get_extension(fn)
-- get the file extension
	local fpat= "(.+)%.(%w+)"
	local s,e,a,b= fn:find(fpat,1)
	--print(s,e,a,b)
	return string.lower(b)
end



function path_split(str, pat)
   local t = {}
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t, table.maxn(t)
end



function get_dir(gf)
	-- first split then recombine excluding the last value
	local t, n = path_split(gf, g.path_sep)
	local tgf=""
	local i= 1
	while i < n do
		tgf= tgf .. t[i] .. g.path_sep
		i= i + 1
	end
	--print(tgf)
	return tgf, t[n]
end


function save_image()
	-- Save the base image and the movable image if available to a new image and return it
	-- First see if there is a pending movable image

	local lx, ly	-- lowest x and y
	local nw, nh 	-- new width and height
	local nb={}		-- new x and y for base image
	local nj={}		-- new x and y for movable image


	if g.image_avail == true then
		-- find the rotated vertices of both images
		local jrc= rotate_vertices(m.x,m.y,m.w,m.h,g.rotate)
		-- calculate the new lower left corner of the images
		local tjx, tjy= new_ll_corner(jrc)
		--print("new movable ll corner tjx, tjy",tjx, tjy)

		local brc= rotate_vertices(b.x,b.y,b.w,b.h,g.base_rotate)
		local tbx, tby= new_ll_corner(brc)
		--print("new base ll corner tbx, tby",tbx, tby)


		-- need to deal with two possibly rotated inages

		if tjx < tbx then
			lx= tjx
		else
			lx=tbx
		end
		if tjy < tby then
			ly= tjy
		else
			ly= tby
		end
		nb.x= b.x - lx --b image handle translated to the frame of reference of the new  composite image
		nb.y= b.y - ly --b image handle translated to the frame of reference of the new  composite image
		nj.x= m.x - lx --m image handle translated to the frame of reference of the new  composite image
		nj.y= m.y - ly --m image handle translated to the frame of reference of the new  composite image


		-- now get the width and height	of the new image in a similar way but using the upper right corners instead
		local tbux, tbuy= new_ur_corner(brc)
		local tjux, tjuy= new_ur_corner(jrc)

		if tbux > tjux then
			nw= tbux - lx
		else
			nw= tjux - lx
		end
		if tbuy > tjuy then
			nh= tbuy - ly
		else
			nh= tjuy - ly
		end
	else
		-- no movable image so just the base image but it could be rotated
		-- Get the lower left corner
		local brc= rotate_vertices(b.x,b.y,b.w,b.h,g.base_rotate)
		lx, ly= new_ll_corner(brc)

		nb.x=  0
		nb.y=  0


		-- now get the width and height	of the new image in a similar way but using the upper right corners instead
		local tbux, tbuy= new_ur_corner(brc)
		nw= tbux - lx
		nh= tbuy - ly


	end
	--print("nb.x, nb.y, b.x, b.y, nj.x, nj.y, m.x, m.y, lx, ly, nw, nh",nb.x, nb.y, b.x, b.y, nj.x, nj.y, m.x, m.y, lx, ly, nw, nh)


	-- Now create the canvas of the correct size
	local timage = im.ImageCreate(nw, nh, im.RGB, im.BYTE)
	local tcanvas = timage:cdCreateCanvas()  -- Creates a CD_IMAGERGB canvas
	tcanvas:Activate()
		-- set the background colour
	tcanvas:SetBackground(g.bgcolour)
	tcanvas:Clear()


	-- now place the image(s)
	if m.image and g.image_avail == true then
		if g.moveable_image_over == true then
			--first the base then the next image
			draw_image(b.image,tcanvas,g.base_rotate,nb.x, nb.y,b.w,b.h, b.dx, b.dy)		-- then the movable image
			-- temporarily set the alpha of m.image to max then set it back after writing it
			m.image:SetAlpha(g.max_alpha)
			draw_image(m.image,tcanvas,g.rotate,nj.x, nj.y,m.w,m.h, m.dx, m.dy)
			m.image:SetAlpha(g.alpha)
		else
			-- first the next image then the base image
			draw_image(m.image,tcanvas,g.rotate,nj.x, nj.y,m.w,m.h, m.dx, m.dy)
			-- temporarily set the alpha of b.image to max then set it back after writing it
			b.image:SetAlpha(g.max_alpha)
			draw_image(b.image,tcanvas,g.base_rotate,nb.x, nb.y,b.w,b.h, b.dx, b.dy)		-- then the movable image
			b.image:SetAlpha(g.alpha)
		end
	else
		--tcanvas:cdCanvasPutImageRect(b.image, 0, 0, 0, 0, 0, 0, 0, 0)
		--b.image:cdCanvasPutImageRect(tcanvas, 0, 0, 0, 0, 0, 0, 0, 0)
		draw_image(b.image,tcanvas,g.base_rotate,nb.x, nb.y,b.w,b.h, b.dx, b.dy)
	end

	-- kill the canvas
	tcanvas:Kill()
	-- return the image
	return timage
end



-- now get the base image
-- There is no point in going on until we get it
-- look first to see if it is on the clipboard

g.clipboard= iup.clipboard{}

local image_avail= iup.GetAttribute(g.clipboard, "IMAGEAVAILABLE")
if image_avail == "YES" then
	local b = iup.Alarm("Stitcher - Initial Image", "From where do you want to get the initial image?" ,"Clipboard" ,"From file", "No initial image")
	-- Shows a message for each selected button
	if b == 1 then
		local nimage= iup.GetAttribute(g.clipboard, "NATIVEIMAGE")
		--print("nimage",nimage)
		local cimage= iup.GetNativeHandleImage(nimage)
			--print("clipboard_image",cimage)
		g.baseimage= cimage:Duplicate()
	elseif b == 2 then
		repeat
			gf, gerr = iup.GetFile(g.dir .. g.path_sep .. default.filetype_filter)
			while gerr ~= 0 do
				--print(gf, gerr)
				gf, gerr = iup.GetFile(g.dir .. g.path_sep .. default.filetype_filter)
			end

			g.dir= get_dir(gf)
			g.baseimage = im.FileImageLoad(gf) -- directly load the image at index 0. it will open and close the file
		until g.baseimage
	else
		g.baseimage = im.ImageCreate(1, 1, im.RGB, im.BYTE)
	end
else
	local b = iup.Alarm("Stitcher - Initial Image", "Do you want to select an initial image from a file?" ,"Yes" ,"No initial image")
	-- Shows a message for each selected button
	if b == 1 then
		repeat
			gf, gerr = iup.GetFile(g.dir .. g.path_sep .. default.filetype_filter)
			while gerr ~= 0 do
				--print(gf, gerr)
				gf, gerr = iup.GetFile(g.dir .. g.path_sep .. default.filetype_filter)
			end

			g.dir= get_dir(gf)
			g.baseimage = im.FileImageLoad(gf) -- directly load the image at index 0. it will open and close the file
		until g.baseimage
	else
		g.baseimage = im.ImageCreate(1, 1, im.RGB, im.BYTE)
	end
end

g.baseimage:AddAlpha()
g.baseimage:SetAlpha(g.max_alpha)

-- now that we have the image set up the global variables
-- first the base image


b.w= g.baseimage:Width()
b.h= g.baseimage:Height()


-- then the virtual area
if b.h  + 2 * g.edge < g.virtual_h then
	v.h= g.virtual_h
else
	v.h= b.h + 2 * g.edge
end
if b.w  + 2 * g.edge < g.virtual_w then
	v.w= g.virtual_w
else
	v.w= b.w + 2 * g.edge
end
--print("Virtual area x,y,w,h", v.x, v.y, v.w, v.h)


-- create the IUP canvas and set up the scrollbars.

--

cnv = iup.canvas{
rastersize = g.canvas_size,
border = "NO",
cursor = "ARROW",
scrollbar= "YES",
xautohide= "NO",
yautohide= "NO"}



-- set up the screen values
s.x= g.virtual_sx
s.y= g.virtual_sy
s.w= g.canvas_w
s.h= g.canvas_h

-- scrollbars are based on the virtual area and the screen

cnv.xmin=v.x
cnv.xmax=v.w
cnv.posx=s.x
cnv.dx=s.w
cnv.ymin=v.y
cnv.ymax= v.h
cnv.posy=v.h - s.y
cnv.dy=s.h




-- put the image on the canvas
b.image = g.baseimage:Duplicate()
b.x= s.x
b.y= s.y
-- set up the ll corner position delta, these are 0 as not rotated
b.dx= 0 --not initially rotated
b.dy= 0 --not initially rotated

--print("Base Image x,y,w,h", b.x, b.y, b.w, b.h)

iup.SetLanguage(g.language)


function temp_filename(jc)
	-- return a temporary filename, the name depends on whether we are recording history (tmp0.png, tmp1.png,...) or not (tmp.png),
	local tfn
	local ltmpdir
	if g.tmpdir and g.path_sep ~= "" then
		ltmpdir= g.tmpdir .. g.path_sep
	else
		ltmpdir= ""
	end
	if g.history == false then
		tfn= ltmpdir .. g.tmpname .. "." .. g.tmpsuffix
	else
		tfn= ltmpdir .. g.tmpname .. jc .. "." .. g.tmpsuffix
	end
	return tfn
end

-- save the initial image into first tmp file

b.image:Save(temp_filename(g.joins_count), string.upper(g.tmpsuffix))
g.joins_count= g.joins_count+1
g.max_joins_count= g.joins_count



function on_off(b)
	local oo
	if b == true then
		oo= "ON"
	else
		oo= "OFF"
	end
	return oo
end

-- Creates items, sets its shortcut keys and deactivates edit item
item_show = iup.item {title = "Show"}
item_hide = iup.item {title = "Hide\tCtrl+H"}
item_edit = iup.item {title = "Edit", active = "NO"}
item_exit = iup.item {title = "Exit"}
item_image = iup.item {title = "Next Image"}
item_join = iup.item {title = "Join", active = "NO"}
item_save = iup.item {title = "Save As..."}
item_increase = iup.item {title = "Increase"}
item_bgcolour = iup.item {title = "Set Background Colour"}
item_fgcolour = iup.item {title = "Set Foreground Colour"}
item_options = iup.item {title = "Options"}
item_reset = iup.item {title = "Reset"}
item_about = iup.item {title = "About"}
item_guide = iup.item {title = "Overview"}
item_lockbase = iup.item {title = "Lock Base Image", value="ON"}
item_paste = iup.item {title = "Paste ",key = "K_cV"}
item_copy = iup.item {title = "Copy",key = "K_cC"}
item_rotate_image= iup.item {title = "Rotate Image"}
item_under= iup.item {title = "Moveable Image Under",value="OFF"}
item_over= iup.item {title = "Moveable Image Over",value="ON"}
item_history= iup.item {title = "Enable Edit History",value= on_off(g.history)}
item_paste_save= iup.item {title = "Enable saving pasted images",value= on_off(g.paste_save)}
item_goto= iup.item {title = "Undo join",key = "K_g",active = "NO"}
item_transparency= iup.item {title = "Transparency"}
item_lines= iup.item {title = "Alignment Grid", value="OFF"}
item_rectangle= iup.item {title = "Rectangle", value="OFF"}



function item_lines:action()
	if item_lines.value == "OFF" then
		item_lines.value= "ON"
		g.line_on= true
		else
		item_lines.value= "OFF"
		g.line_on= false
	end
	cnv:action(cnv.posx, cnv.posy)
end


function item_rectangle:action()
	if item_rectangle.value == "OFF" then
		item_rectangle.value= "ON"
		g.rectangle= true
	else
		item_rectangle.value= "OFF"
		g.rectangle= false
	end
	cnv:action(cnv.posx, cnv.posy)
end


function item_paste:action()
-- copy the clipboard in as the movable image


--local clipboard= iup.clipboard{}
	local image_avail= iup.GetAttribute(g.clipboard, "IMAGEAVAILABLE")

	if image_avail == "YES" then
		local nimage= iup.GetAttribute(g.clipboard, "NATIVEIMAGE")
		--print("nimage",nimage)
		local cimage= iup.GetNativeHandleImage(nimage)
		--print("clipboard_image",cimage)
		m.image= cimage:Duplicate()
		if 	g.moveable_image_over == true then
			m.image:SetAlpha(g.alpha)
		end
		m.w= cimage:Width()
		m.h= cimage:Height()
		--print("Image height", m.h)
		if g.image_avail ~= true then
			-- if there is already an image on the screen then use the existing position
			m.x= s.x
			m.y= s.y
			m.dx= 0 --not initially rotated
			m.dy= 0 --not initially rotated
		end
		if g.paste_save == true then
			save_pasted_image(cimage, m.w,m.h)
		end
		g.image= cimage:Duplicate()
		g.image_avail= true
		g.rotate= 0
		item_join.active= "YES"
		cnv:action(cnv.posx, cnv.posy)
		-- automatically lock the baseimage
		item_lockbase.value= "ON"
		g.lock_base= true
	else
		iup.Message('Simple Stitcher','No image on clipboard to paste')
	end
	cnv:action(cnv.posx, cnv.posy)
end



function item_copy:action()
	-- copy the the current base and movable images onto the clipboard
	-- get the image
	local timage= save_image()
	-- convert it to native format
	local cimage= iup.GetImageNativeHandle(timage)
	-- store it on the clipboard
	iup.StoreAttribute(g.clipboard, "NATIVEIMAGE", cimage)
end


function item_lockbase:action()
	--print("item_lockbase.value, g.lock_base", item_lockbase.value, g.lock_base)
	if item_lockbase.value == "OFF" then
		item_lockbase.value= "ON"
		g.lock_base= true
	else
		if g.image_avail == false then
			item_lockbase.value= "OFF"
			g.lock_base= false
		else
			iup.Message('Simple Stitcher','Base image can only be unlocked when there is no movable image ')
		end
	end
end


function item_rotate_image:action()
	if g.lock_base == true then
		if g.image_avail == true then
			g.rotate= rotate_dialogue(g.rotate)
			m.dx, m.dy= rotate_degrees(g.image, m.image, g.rotate, m.x, m.y, m.w, m.h)
		else
			iup.Message('Simple Stitcher','Base image can only be rotated when unlocked ')
		end
	else
		g.base_rotate= rotate_dialogue(g.base_rotate)
		b.dx, b.dy= rotate_degrees(g.baseimage, b.image, g.base_rotate, b.x, b.y, b.w, b.h)
	end
	cnv:action(cnv.posx, cnv.posy)
end


function rotate_dialogue(gangle)
	local pangle= 0
	local tangle= 0
	local clockwise= 0

	if gangle ~= 0 then
		pangle= -gangle -- negative because clockwise
		if pangle < 0 then
			pangel= 360 + pangle
		end
	end

	local ret, pangle, clockwise = iup.GetParam("Currently rotated " .. pangle .. " clockwise", nil,"Angle: %r[0,360,0.1]{Rotation Angle}\n" .. "Direction: %o|Clockwise|Counterclockwise|\n",pangle,clockwise)
	--print(ret, pangle)
	if (ret == true) then
		if pangle > 0 and pangle < 360 then
			if clockwise ~= 0 then
				tangle= pangle - 360 -- negative because clockwise
			else
				tangle= -pangle -- negative because clockwise
			end
		else
			tangle= 0
		end
	else
		tangle= gangle
	end
	return tangle
end


function item_transparency:action()
	local ret, talpha = iup.GetParam("Transparency currently " .. g.alpha, nil,"Transparency: %i[0,255,1]{Rotation Angle}\n",g.alpha)
	--print(ret, pangle)
	if (ret == true) then
		g.alpha= talpha
		if g.lock_base == true then
			if g.image_avail == true then
				if g.moveable_image_over == false then
					b.image:SetAlpha(g.alpha)
					g.baseimage:SetAlpha(g.alpha)
				else
					m.image:SetAlpha(g.alpha)
					g.image:SetAlpha(g.alpha)
				end
			end
		end
	end
	cnv:action(cnv.posx, cnv.posy)
end


function item_goto:action()
	if g.history == true then
		if g.image_avail == true then
			iup.Message('Simple Stitcher','Note that the currently loaded new image will remain on the canvas')
		end
		if g.joins_count >= 0 then
			local ret, jc = iup.GetParam("Showing (currently number " .. g.joins_count -1  .. " of 0 to " .. g.max_joins_count -1  ..")", nil,"Join: %i[0," .. g.max_joins_count -1 .. ",1]\n",g.joins_count-1)
			print(ret, jc, g.joins_count, g.max_joins_count)
			if (ret == true) then
				-- load the stored join image
				b.image= im.FileImageLoad(temp_filename(jc)) -- directly load the image at the chosen join. it will open and close the file
				g.joins_count= jc + 1
				cnv:action(cnv.posx, cnv.posy)
			end
		else
			iup.Message('Simple Stitcher','No joins to undo')
		end
	else
		iup.Message('Simple Stitcher','Edit history not enabled')
	end
end


function inner_rectangle(w,h,c,s)
-- width height cos(angle), sin(angle)
	local bwidth= w * c + h * s
	local bheight= h * c + w * s
	local wr= (w*c)/bwidth
	local hr= (h*c)/bheight
	--print (bwidth, bheight, wr, hr)
	local olw= w * wr
	local osw= w - olw
	local olh= h * hr
	local osh= h - olh
	local swidth= osh/s
	local sheight= olh/c
	--print(swidth, sheight)
	return swidth, sheight
end

function item_save:action()
	--print("item_save:action()")
	local attab= {DIALOGTYPE= "SAVE",TITLE= "Save Image", NOCHANGEDIR= "NO", DIRECTORY=g.dir, FILTER=default.filetype_filter}
	local filedlg = iup.filedlg(attab)

	-- Shows file dialog in the center of the screen
	filedlg:popup (iup.ANYWHERE, iup.ANYWHERE)

	-- Gets file dialog status
	local status = filedlg.status

	if status == "1" or status == "0" then
		-- 0 exists or 1 new file
		local timage= save_image()
		local fdir, fn= get_dir(filedlg.value)
		local ftype= default.filetypes[get_extension(fn)]
		if ftype then
			timage:Save(fn, ftype)
		else
			timage:Save(fn, "PNG")
			iup.Message('Image Save','The file extension was not recognised. The image was saved as type PNG.')
		end
		timage:Destroy()
		g.dir= fdir
	elseif status == "-1" then
		--iup.Message("Save","Operation canceled")
	end
	iup.Destroy(filedlg)
  return iup.DEFAULT
end


function item_over:action()
--print("item_over:action()")
	if g.image_avail == true then
		if item_over.value == "OFF" then
			item_over.value= "ON"
			item_under.value= "OFF"
			g.moveable_image_over= true
			b.image:SetAlpha(g.max_alpha)
			g.baseimage:SetAlpha(g.max_alpha)
			m.image:SetAlpha(g.alpha)
			g.image:SetAlpha(g.alpha)
		end
		cnv:action(cnv.posx, cnv.posy)
	else
		iup.Message('Moveable image over','There is no moveable image')
	end
end

function item_under:action()
--print("item_under:action()")
	if g.image_avail == true then
		if item_over.value == "ON" then
			item_over.value= "OFF"
			item_under.value= "ON"
			g.moveable_image_over= false
			b.image:SetAlpha(g.alpha)
			g.baseimage:SetAlpha(g.alpha)
			m.image:SetAlpha(g.max_alpha)
			g.image:SetAlpha(g.max_alpha)
		end
		cnv:action(cnv.posx, cnv.posy)
	else
		iup.Message('Moveable image under','There is no moveable image')
	end
end

function item_history:action()
--print("item_history:action()")
	if item_history.value == "ON" then
		item_history.value= "OFF"
		g.history= false
		item_goto.active = "NO"
	else
		item_history.value= "ON"
		g.history= true
		item_goto.active = "YES"
	end
end

function item_paste_save:action()
--print("item_paste_save:action()")
	if item_paste_save.value == "ON" then
		item_paste_save.value= "OFF"
		g.paste_save= false
	else
		item_paste_save.value= "ON"
		g.paste_save= true
	end
end


function item_image:action()
--print("item_image:action()")

local  f, err = iup.GetFile(g.dir .. g.path_sep .. default.filetype_filter)
	if err == 0 then
		local image = im.FileImageLoad(f) -- directly load the image at index 0. it will open and close the file
		if image then
			image:AddAlpha()
			g.image= image:Duplicate()
			g.image:SetAlpha(g.max_alpha)
			if 	g.moveable_image_over == true then
				image:SetAlpha(g.alpha)
			end
			m.w= image:Width()
			m.h= image:Height()
			--print("Image height", m.h)
			if g.image_avail ~= true then
				-- if there is already an image on the screen then use the existing position
				m.x= s.x
				m.y= s.y
				m.dx= 0 --not initially rotated
				m.dy= 0 --not initially rotated
			end
			m.image= image:Duplicate()
			g.rotate= 0
			g.image_avail= true
			item_join.active= "YES"
			cnv:action(cnv.posx, cnv.posy)
		else
			iup.Message('Next Image','Not a valid image format')
		end
	elseif err == 1 then
	  iup.Message("Next Image", f)
	elseif err == -1 then
	  iup.Message("Next Image", "Operation canceled")
	elseif err == -2 then
	  iup.Message("Next Image", "Allocation error")
	elseif err == -3 then
	  iup.Message("Next Image", "Invalid parameter")
	end
	-- automatically lock the baseimage
	item_lockbase.value= "ON"
	g.lock_base= true
  return iup.DEFAULT
end


function item_join:action()
	-- first show an in progress message on the screen
	--cd.cdCanvasText(cnv, s.x, s.y, "Saving and redloading image")
	if g.image_avail then
		item_image.active= "NO"
		cnv.canvas:Font("Courier", cd.PLAIN, 30)
		cnv.canvas:TextAlignment(cd.CENTER)
		cnv.canvas:Text(s.w/2, s.h/2, "Saving image\n to " .. temp_filename(g.joins_count))
		cnv.canvas:Flush()
		--print(b.x, b.y, m.x, m.y)
		b.x, b.y= save_canvas(b.image, m.image, b.x, b.y, m.x, m.y, b.w, b.h, m.w, m.h)
		--print(b.x, b.y)
		-- load the saved file back in
		g.baseimage = im.FileImageLoad(temp_filename(g.joins_count)) -- directly load the image at g.joins_count. it will open and close the file
		g.joins_count= g.joins_count+1
		g.max_joins_count= g.joins_count
		if g.history == true then
			item_goto.active = "YES" -- in case it is off by default set it on at the first join
		end
		b.image = g.baseimage:Duplicate()
		b.w= b.image:Width()
		b.h= b.image:Height()
		m.image= nil
		g.image_avail= false
		item_join.active= "NO"
		item_image.active= "YES"
		g.rotate= 0
		g.base_rotate= 0
		cnv:action(cnv.posx, cnv.posy)
	else
		iup.Message('Join','No image to Join\n to the base image')
	end
end


function item_exit:action()
	--print("item_exit:action()")
  return iup.CLOSE
end


function item_bgcolour:action()
local rc,gc,bc
	rc,gc,bc= cd.DecodeColor(g.bgcolour)
	rc,gc,bc= iup.GetColor(100, 100,rc,gc,bc)
	if rc and bc and gc then
		g.bgcolour= cd.EncodeColor(rc, gc, bc)
		cnv.dbuffer:SetBackground(g.bgcolour)
	end
	cnv:action(cnv.posx, cnv.posy)
end


function item_fgcolour:action()
local rc,gc,bc
	rc,gc,bc= cd.DecodeColor(g.fgcolour)
	rc,gc,bc= iup.GetColor(100, 100,rc,gc,bc)
	if rc and bc and gc then
		g.fgcolour= cd.EncodeColor(rc, gc, bc)
		cnv.dbuffer:SetForeground(g.fgcolour)
	end
	cnv:action(cnv.posx, cnv.posy)
end



function item_increase:action()
	--print("item_increase:action()")
	v.w= v.w+g.virtual_step * 2
	v.h= v.h+g.virtual_step * 2
	b.x= b.x + g.virtual_step
	b.y= b.y + g.virtual_step
	if g.image_avail == true then
		m.x= m.x + g.virtual_step
		m.y= m.y + g.virtual_step
	end
	s.x= s.x + g.virtual_step
	s.y= s.y + g.virtual_step
	cnv.posx= cnv.posx + g.virtual_step
	cnv.posy= cnv.posy + g.virtual_step
	cnv.xmax= v.w
	cnv.ymax= v.h
	cnv.dx= cnv.dx -- just needed to trigger a redraw
	cnv.dy= cnv.dy -- just needed to trigger a redraw
	cnv:action(cnv.posx, cnv.posy)
  return iup.DEFAULT
end


g.params={}
g.params.n=15
g.params.touch={}
g.params.ctrl={}
g.params.labels={}

g.params.labels[0]="Transparency Step"
g.params.ctrl[0]=": %i[0,255]\n"
g.params.labels[1]=	"Minimum Transparency"
g.params.ctrl[1]=":  %i[0,255]\n"
g.params.labels[2]=	"Temporary File Name"
g.params.ctrl[2]=":  %s\n"
g.params.labels[3]=	"Temporary File suffix"
g.params.ctrl[3]=":  %s\n"
g.params.labels[4]=	"Temporary File Directory"
g.params.ctrl[4]=":  %f[DIR|*|" .. g.tmpdir .. "|NO|NO]\n"
g.params.labels[5]=	"Line Width"
g.params.ctrl[5]=":  %i[1,10]\n"
g.params.labels[6]=	"Initial Virtual Canvas Width"
g.params.ctrl[6]=":  %i[1000]\n"
g.params.labels[7]=	"Initial Virtual Canvas Height"
g.params.ctrl[7]=":  %i[1000]\n"
g.params.labels[8]=  "Virtual Canvas increase step"
g.params.ctrl[8]=":  %i[100]\n"
g.params.labels[9]=	"Initial Window Width"
g.params.ctrl[9]=":  %i[200]\n"
g.params.labels[10]= "Initial Window Height"
g.params.ctrl[10]=":  %i[200]\n"
g.params.labels[11]= "Initial Base Image x"
g.params.ctrl[11]=":  %i[0]\n"
g.params.labels[12]= "Initial Base Image y"
g.params.ctrl[12]=":  %i[0]\n"
g.params.labels[13]= "Initial Canvas Edge y"
g.params.ctrl[13]=":  %i[0]\n"
g.params.labels[14]= "Rotation per keypress"
g.params.ctrl[14]=":  %r[0.01,359.99]\n"
g.params.labels[15]=	"Pasted File Name"
g.params.ctrl[15]=":  %s\n"

function param_ctrl_string()
	local s=""
	for i=0,g.params.n do
		s= s .. "(" .. i .. ") " .. g.params.labels[i] .. g.params.ctrl[i]
	end
	return s
end


function less_than(dialog, i, j, r,s)
-- returns 1 if i<j otherwise 0 and an error string
	local ret= r
	local str=s
	local p_i = iup.GetParamParam(dialog, i)
	local p_j = iup.GetParamParam(dialog, j)
	if tonumber(p_i.value) >= tonumber(p_j.value) then
		ret= 0
		str= str .. "(" .. i .. ") " ..g.params.labels[i] .. " = " .. p_i.value .. " must be less than  (" .. j ..") " .. g.params.labels[j] .. " = " .. p_j.value .. "\n"
	end
	return ret, str
end

function greater_than(dialog, i, j, r, s)
-- returns 1 if i>j otherwise 0 and an error string
	local ret= r
	local str= s
	local p_i = iup.GetParamParam(dialog, i)
	local p_j = iup.GetParamParam(dialog, j)
	if tonumber(p_i.value) <= tonumber(p_j.value) then
		ret= 0
		str= str .. "(" .. i .. ") " ..g.params.labels[i] .. " = " .. p_i.value .. " must be greater than  (" .. j ..") " .. g.params.labels[j] .. " = " .. p_j.value .. "\n"
	end
	return ret, str
end

function twice_as_big_as(dialog, i, j, r, s)
-- returns 1 if i>j*2 otherwise 0 and an error string
	local ret= r
	local str= s
	local p_i = iup.GetParamParam(dialog, i)
	local p_j = iup.GetParamParam(dialog, j)
	if tonumber(p_i.value) <= tonumber(p_j.value)*2 then
		ret= 0
		str= str .. "(" .. i .. ") " ..g.params.labels[i] .. " = " .. p_i.value .. " must be more than twice as big as (" .. j ..") " .. g.params.labels[j] .. " = " .. p_j.value .. "\n"
	end
	return ret, str
end

function less_than_half_of(dialog, i, j, r, s)
-- returns 1 if i<j*2 otherwise 0 and an error string
	local ret= r
	local str= s
	local p_i = iup.GetParamParam(dialog, i)
	local p_j = iup.GetParamParam(dialog, j)
	if tonumber(p_i.value) >= tonumber(p_j.value)*2 then
		ret= 0
		str= str .. "(" .. i .. ") " ..g.params.labels[i] .. " = " .. p_i.value .. " must be less than half the size of (" .. j ..") " .. g.params.labels[j] .. " = " .. p_j.value .. "\n"
	end
	return ret, str
end

g.params.func={}

g.params.func[4]=
function (dialog,i)
	local ret= 1
	local s=""
	local param1 = iup.GetParamParam(dialog, i)
	local r
	if param1.value == "" then
		r= os.execute("ls")
	else
		r= os.execute("ls " .. [["]] .. param1.value .. [["]])
	end
	if r == g.os_fail then
		ret= 0
		s= "(" .. i .. ") " ..g.params.labels[i] .. " = " .. param1.value .. " does not exist\n"
	end
	return ret, s
end

g.params.func[6]=
function (dialog,i)
	local r= 1
	local s=""
	r,s= greater_than(dialog, i, 9, r, s)
	r,s= twice_as_big_as(dialog, i, 13, r, s)
	r,s= greater_than(dialog, i, 11, r, s)
	return r, s
end

g.params.func[7]=
function (dialog,i)
	local r= 1
	local s=""
	r,s= greater_than(dialog, i, 10, r, s)
	r,s= twice_as_big_as(dialog, i, 13, r, s)
	r,s= greater_than(dialog, i, 12, r, s)
	return r, s
end

g.params.func[11]=
function (dialog,i)
	local r= 1
	local s=""
	r,s= less_than(dialog, i, 6, r, s)
	return r, s
end

g.params.func[12]=
function (dialog,i)
	local r= 1
	local s=""
	r,s= less_than(dialog, i, 7, r, s)
	return r, s
end

g.params.func[13]=
function (dialog,i)
	local r= 1
	local s=""
	r,s= less_than_half_of(dialog, i, 6, r, s)
	r,s= less_than_half_of(dialog, i, 7, r, s)
	return r, s
end



function options_check(dialog, param_index)
	local ret=1 -- ok
	local s=""
	local tpi= tonumber(param_index)
	--print("tpi=", tpi, g.params.touch[tpi])
	if (tpi == -1) then -- ok
		for i=0,g.params.n do -- run through them in order
			if g.params.touch[i] ~= nil and type(g.params.func[i]) == "function" then
				local tret, ts= g.params.func[i](dialog,i)
				ret= ret * tret -- if ret becomes 0 it will stay 0
				--print("tret ret", tret, ret)
				s= s .. ts
			end
		end
		if ret == 0 then
			iup.Message('Simple Stitcher, Problem', s)
		end
	elseif tpi >= 0 and g.params.touch[tpi] == nil then
		g.params.touch[tpi]= 1
	end
	return ret
end


function item_options:action()
	--print("item_options:action()")
	--reset the touch table to be empty & let gc clean it up
	g.params.touch= nil
	g.params.touch= {}
	-- update the control string with the value of the current tmpdir
	g.params.ctrl[4]=":  %f[DIR|*|" .. g.tmpdir .. "|NO|NO]\n"

	local ret
	local ps
	if g.paste_save == true then
		ps= 1
	else
		ps= 0
	end
	ret,
	lalpha_step, lmin_alpha, ltmpname, ltmpsuffix, ltmpdir, lline_width, lvirtual_w, lvirtual_h, lvirtual_step, lwindow_w, lwindow_h, lvirtual_sx, lvirtual_sy, ledge, lrotate_step, lpastename=
	iup.GetParam("Options", options_check,param_ctrl_string(),
	g.alpha_step, g.min_alpha, g.tmpname, g.tmpsuffix, g.tmpdir, g.line_width, g.virtual_w, g.virtual_h, g.virtual_step, g.window_w, g.window_h, g.virtual_sx, g.virtual_sy, g.edge, g.rotate_step, g.pastename)
	--print("ret", ret)
	if (ret == true) then
		local error= false
		local error_text= ""
		g.alpha_step= lalpha_step
		g.min_alpha= lmin_alpha
		g.tmpname= ltmpname
		g.tmpsuffix= ltmpsuffix
		g.tmpdir= ltmpdir
		g.line_width= lline_width
		g.virtual_w= lvirtual_w
		g.virtual_h= lvirtual_h
		g.virtual_step= lvirtual_step
		g.window_w= lwindow_w
		g.window_h= lwindow_h
		g.virtual_sx= lvirtual_sx
		g.virtual_sy= lvirtual_sy
		g.edge= ledge
		g.rotate_step= lrotate_step
		g.pastename= lpastename
	end
	cnv:action(cnv.posx, cnv.posy)
	return iup.DEFAULT
end


function item_reset:action()
	g.alpha_step= default.alpha_step
	g.min_alpha= default.min_alpha
	g.tmpname= default.tmpname
	g.tmpsuffix= default.tmpsuffix
	g.tmpdir= default.dir
	g.line_width= default.line_width
	g.bgcolour= default.bgcolour
	g.fgcolour= default.fgcolour
	g.history= default.history
	g.virtual_w= default.virtual_w
	g.virtual_h= default.virtual_h
	g.virtual_step= default.virtual_step
	g.window_w= default.window_w
	g.window_h= default.window_h
	g.virtual_sx= default.virtual_sx
	g.virtual_sy= default.virtual_sy
	g.edge= default.edge
	g.rotate_step= default.rotate_step
	g.pastename= default.pastename
	cnv:action(cnv.posx, cnv.posy)
	return iup.DEFAULT
end


function item_about:action()
	--print("item_about:action()")
	iup.Message('Simple Stitcher, About','Copyright 2013 \n Michael Casey\n a simple map stitching program\n Uses lua, iup, cd, im')
  return iup.DEFAULT
end


function item_guide:action()
	--print("item_guide:action()")
	iup.Message('Simple Stitcher, Overview',[[Starting from an initial base image, sequentially add and join images until the final composite image is complete.
There is always a base image and a moveable image. The moveable image can be over the base image (default) or under the base image. The upper image (moveable or base) is
partially transparent to aid alignment.

The mouse keys (Right hand mouse) have the following functions associated with them:

	Left click: Drag moveable image (or base image when unlocked) or canvas in window when not pointing at draggable image
	Right click: Set background colour to the pixel under the cursor of either moveable or base image
	Wheel rotate: Reduce/Increase transparency of upper image by 1 step
	Wheel click: Toggle which image is upper image and lower image

The keyboard keys to use are:

    qwedcxza: For 1 pixel Movement in the directions NE,N,NE,W,SE,S,SW,W
	s:        (Flash) Hide the movable image on key down
			  and it reappears on key up
	j:        Join the movable image to the base image
	bm:		  Rotate clockwise/anticlockwise by X degrees (configurable)
	n:		  Reset rotation to 0 degrees

1. Prepare a set of images with a usable amount of overlap and organised to work left to right and top to bottom
2. Select the first (base)image that could be in the top left hand corner of the final composite image
2a. Set the background colour now, don't change it
3. Load the next (movable) image and use the mouse to drag the movable image to roughly where it should be over the baseimage (the overlapping images will appear fuzzy)
4. Use the flash, quickly press and release the s key, the eye will pick up two (apparent) movements
4a. The first movement is when the movable images disappears and the eye shifts focus from the features in the movable image to the same features in the baseimage,
4b. The second movement occurs when the movable image reappears and the eye shifts focus back to the features on the movable image
4c. The better and closer the overlaps are aligned the more obvious the apparent movement.
5. Press the movement key in the SAME direction as the FIRST apparent movement. Keep on pressing the appropriate direction keys until there is no apparent movement.
6. When there is no apparent movement the overlaps between the base and movable image are aligned and the images can be joined (the overlapping images will appear sharp)
7. Load the next image and repeat the process

Notes:
1. What is a usable amount of overlap? -- it depends on the detail in the images: a few tens of pixels for sat photos is good; more, for relatively featureless maps with solid colours
2. What do you mean by organised? -- For example: capture images left to right and top to bottom and number them 1-1, 1-2, 1-3, 2-1, 2-2, ...
2a, What if I have captured my images right to left and bottom to top? -- unlock and move the base image and/or keep on increasing the canvas size when you run out of (virtual) canvas
3. What if I choose the wrong next image? -- Choose next image again and the current movable image will be replaced.
4. Choose your background colour at the start and don't change it as it is saved into the base images.
4a. For example, if making a composite map of an island, sample the sea (right mouse key) of the first image and use that colour as the bachground colour.

Useful tools:
1. Use the alignment grid to align Lat&Long lines on a rotated map image
2. Use the rectangle around the base map to get the composite image roughly square.
3. Set the background using the first image you load and then don't change it after that  (assuming the first image has the right colour).]])
  return iup.DEFAULT
end

function save_pasted_image(jimage, jw,jh)

	-- create the canvas of the correct size
	local timage = im.ImageCreate(jw, jh, im.RGB, im.BYTE)
	local tcanvas = timage:cdCreateCanvas()  -- Creates a CD_IMAGERGB canvas
	tcanvas:Activate()
		-- set the background colour
	tcanvas:SetBackground(g.bgcolour)
	tcanvas:Clear()
	jimage:SetAlpha(g.max_alpha)
	draw_image(jimage,tcanvas,0,0, 0, jw, jh, 0, 0)

	-- kill the canvas
	tcanvas:Kill()
	-- save the image

	timage:Save(temp_pastename(g.paste_count), string.upper(g.tmpsuffix))
	timage:Destroy()
	g.paste_count= g.paste_count + 1
end



function save_canvas(bimage,jimage, bx, by, jx, jy, bw, bh, jw,jh)
	--print("bx, by, jx, jy, bw, bh, jw,jh", bx, by, jx, jy, bw, bh, jw,jh)

	-- find the rotated vertices of both images
	local brc= rotate_vertices(bx,by,bw,bh,g.base_rotate)
	local jrc= rotate_vertices(jx,jy,jw,jh,g.rotate)

	-- calculate the new lower left corner of the images
	local tbx, tby= new_ll_corner(brc)
	local tjx, tjy= new_ll_corner(jrc)

	--print(tbx, tby)
	--print(tjx, tjy)

	local lx, ly	-- lowest x and y, which will become the new handle pf the composite image
	local nb={}
	local nj={}
	if tjx < tbx then
		lx= tjx
	else
		lx=tbx
	end
	if tjy < tby then
		ly= tjy
	else
		ly= tby
	end
	nb.x= bx - lx --b image handle translated to the frame of reference of the new  composite image
	nb.y= by - ly --b image handle translated to the frame of reference of the new  composite image
	nj.x= jx - lx --m image handle translated to the frame of reference of the new  composite image
	nj.y= jy - ly --m image handle translated to the frame of reference of the new  composite image

	-- now get the width and height	of the new image in a similar way but using the upper right corners instead
	local tbux, tbuy= new_ur_corner(brc)
	local tjux, tjuy= new_ur_corner(jrc)
	local nw, nh
	if tbux > tjux then
		nw= tbux - lx
	else
		nw= tjux - lx
	end
	if tbuy > tjuy then
		nh= tbuy - ly
	else
		nh= tjuy - ly
	end


	--print("nb.x, nb.y, nj.x, nj.y, nw, nh ", nb.x, nb.y, nj.x, nj.y, nw, nh)
	-- Now create the canvas of the correct size
	local timage = im.ImageCreate(nw, nh, im.RGB, im.BYTE)
	local tcanvas = timage:cdCreateCanvas()  -- Creates a CD_IMAGERGB canvas
	tcanvas:Activate()
		-- set the background colour
	tcanvas:SetBackground(g.bgcolour)
	tcanvas:Clear()

	if g.moveable_image_over == true then
		draw_image(bimage,tcanvas,g.base_rotate,nb.x, nb.y, bw, bh, b.dx, b.dy)
		if g.image_avail == true and g.flash == false then
			-- temporarily set the alpha of jimage to max then set it back after writing it
			jimage:SetAlpha(g.max_alpha)
			draw_image(jimage,tcanvas,g.rotate,nj.x, nj.y, jw, jh,  m.dx, m.dy)
			jimage:SetAlpha(g.alpha)
		end
	else
		if g.image_avail == true then
			draw_image(jimage,tcanvas,g.rotate,nj.x, nj.y, jw, jh,  m.dx, m.dy)
		end
		-- temporarily set the alpha of bimage to max then set it back after writing it
		bimage:SetAlpha(g.max_alpha)
		draw_image(bimage,tcanvas,g.base_rotate,nb.x, nb.y, bw, bh, b.dx, b.dy)
		bimage:SetAlpha(g.alpha)
	end

	-- kill the canvas
	tcanvas:Kill()
	-- save the image

	timage:Save(temp_filename(g.joins_count), string.upper(g.tmpsuffix))
	timage:Destroy()
	return lx, ly
end



function temp_pastename(jc)
	local ltmpdir
	if g.tmpdir and g.path_sep ~= "" then
		ltmpdir= g.tmpdir .. g.path_sep
	else
		ltmpdir= ""
	end
	return ltmpdir .. g.pastename .. jc .. "." .. g.tmpsuffix
end
-- Main


-- Create menus
menu_file = iup.menu {item_save,item_exit}
menu_ontop = iup.menu {item_over,item_under}
submenu_ontop = iup.submenu {menu_ontop; title = "Over/Under"}
menu_edit = iup.menu {item_history, item_goto, item_paste_save, item_copy, item_paste}
menu_canvas = iup.menu { item_bgcolour, item_fgcolour, item_increase, item_lockbase, submenu_ontop, item_transparency}
menu_rotate= iup.menu {item_rotate_image}
menu_tools = iup.menu {item_options,item_reset, item_rectangle, item_lines}
menu_help = iup.menu {item_guide, item_about}

-- Create submenus
submenu_file = iup.submenu {menu_file; title = "File"}
submenu_edit = iup.submenu {menu_edit; title = "Edit"}
submenu_canvas = iup.submenu {menu_canvas; title = "Canvas"}
submenu_rotate = iup.submenu {menu_rotate; title = "Rotate"}
submenu_tools = iup.submenu {menu_tools; title = "Tools"}
submenu_help = iup.submenu {menu_help; title = "Help"}

-- Creates main menu with two submenus
menu = iup.menu{submenu_file, submenu_edit, item_image, item_join, submenu_canvas, item_rotate_image, submenu_tools, submenu_help}
iup.key_open()


function cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
	--print("cnv:map_cb()")
  self.canvas = cd.CreateCanvas(cd.IUP, self)
  local dbuffer = cd.CreateCanvas(cd.DBUFFER, self.canvas);
  self.dbuffer = dbuffer
  	self.canvas:SetBackground(g.bgcolour)
	self.dbuffer:SetBackground(g.bgcolour)
	self.canvas:SetForeground(g.fgcolour)
	self.dbuffer:SetForeground(g.fgcolour)
end

function cnv:unmap_cb()
  local canvas = self.canvas     -- retrieve the CD canvas from the IUP attribute
  local dbuffer = self.dbuffer
  dbuffer:Kill()
  canvas:Kill()
end


function cnv:wheel_cb(delta, x, y, status)
	--print("cnv:wheel_cb(delta, x, y status)", delta, x, y, status)
	g.alpha= g.alpha - delta * g.alpha_step
	if g.alpha < g.min_alpha then
			g.alpha = g.min_alpha
	elseif g.alpha > g.max_alpha then
		g.alpha= g.max_alpha
	end
	if g.lock_base == true then
		if g.image_avail == true then
			if g.moveable_image_over == false then
				b.image:SetAlpha(g.alpha)
				g.baseimage:SetAlpha(g.alpha)
			else
				m.image:SetAlpha(g.alpha)
				g.image:SetAlpha(g.alpha)
			end
		end
	end
	self:action(self.posx, self.posy)
	return iup.DEFAULT
end



function cnv:dropfiles_cb(f, num, x, y)
	-- elem:dropfiles_cb(filename: string; num, x, y: number)
		local image = im.FileImageLoad(f) -- directly load the image at index 0. it will open and close the file
		if image then
			image:AddAlpha()
			image:SetAlpha(g.alpha)
			m.w= image:Width()
			m.h= image:Height()
			--print("Image height", m.h)
			if g.image_avail ~= true then
				-- if there is already an image on the screen then use the existing position
				m.x= s.x
				m.y= s.y
			end
			m.image= image:Duplicate()
			g.baseimage= image:Duplicate()
			g.image_avail= true
			item_join.active= "YES"
			cnv:action(cnv.posx, cnv.posy)
			-- automatically lock the baseimage
			item_lockbase.value= "ON"
			g.lock_base= true
			g.rotate= 0
		else
			iup.Message('Next Image','Not a valid image format')
		end
		im.ImageDestroy(image)
  return iup.IGNORE
end


function draw_image(image,dbuffer,rotate,x,y,w,h,dx,dy)
	--print("image,dbuffer,rotate,x,y,w,h,dx,dy)", image,dbuffer,rotate,x,y,w,h,dx,dy)
	if image then
		if rotate == 0 then
			image:cdCanvasPutImageRect(dbuffer, x, y, 0, 0, 0, 0, 0, 0) --
		else
			-- determine the coords of the rotated corners
			local rc= rotate_vertices(x,y,w,h,rotate)
			--local rc= move_rect(nc, 0,0)
			--show_contents(rc)
			dbuffer:Begin(cd.CLIP)
			dbuffer:Vertex(rc[0].x, rc[0].y)
			dbuffer:Vertex(rc[1].x, rc[1].y)
			dbuffer:Vertex(rc[2].x, rc[2].y)
			dbuffer:Vertex(rc[3].x, rc[3].y)
			dbuffer:End()
			dbuffer:Clip(cd.CLIPPOLYGON)
			image:cdCanvasPutImageRect(dbuffer, x+dx , y+dy, 0, 0, 0, 0, 0, 0, 0)
			dbuffer:Clip(cd.CLIPOFF)
		end
	end
end


function draw_rectangle(dbuffer,rotate,x,y,w,h)
	--print("draw_rectangle(dbuffer,rotate,x,y,w,h)", dbuffer,rotate,x,y,w,h)
	dbuffer:LineWidth(g.line_width)
	dbuffer:LineStyle(cd.DOTTED)
	if rotate == 0 then
		dbuffer:Line(x, y, x, y+h)
		dbuffer:Line(x, y+h, x+w, y+h)
		dbuffer:Line(x+w, y+h, x+w, y)
		dbuffer:Line(x+w, y, x, y)
	else
		-- determine the coords of the rotated corners
		local rc= rotate_vertices(x,y,w,h,rotate)
		dbuffer:Line(rc[0].x, rc[0].y, rc[1].x, rc[1].y)
		dbuffer:Line(rc[1].x, rc[1].y, rc[2].x, rc[2].y)
		dbuffer:Line(rc[2].x, rc[2].y, rc[3].x, rc[3].y)
		dbuffer:Line(rc[3].x, rc[3].y, rc[0].x, rc[0].y)
	end
end


function cnv:action(posx, posy) -- called everytime the IUP canvas needs to be repainted
	--print("posx, posy, s.x, s.y, b.x, b.y, m.x, m.y", posx, posy, s.x, s.y, b.x, b.y, m.x, m.y)
	local dbuffer = cnv.dbuffer     -- retrieve the CD canvas from the IUP attribute
	dbuffer:Activate()
	dbuffer:Clear()
	dbuffer:SetBackground(g.bgcolour)
	dbuffer:SetForeground(g.fgcolour)
	if g.moveable_image_over == true then
		-- the movable image is over the base image
		draw_image(b.image,dbuffer,g.base_rotate,b.x - s.x, b.y - s.y, b.w, b.h, b.dx, b.dy)
		if g.rectangle == true then
			-- draw a box around the baseimage
			draw_rectangle(dbuffer,g.base_rotate,b.x - s.x,b.y - s.y,b.w,b.h)
		end

		if g.image_avail == true and g.flash == false then
			draw_image(m.image,dbuffer,g.rotate,m.x - s.x, m.y - s.y,m.w,m.h, m.dx, m.dy)
		end
	else
		-- the movable image is under the base image
		if g.image_avail == true then
			draw_image(m.image,dbuffer,g.rotate,m.x - s.x, m.y - s.y,m.w,m.h, m.dx, m.dy)
		end
		if g.flash == false then
			draw_image(b.image,dbuffer,g.base_rotate,b.x - s.x, b.y - s.y,b.w,b.h, b.dx, b.dy)
			if g.rectangle == true then
				-- draw a box around the baseimage
				draw_rectangle(dbuffer,g.base_rotate,b.x - s.x,b.y - s.y,b.w,b.h)
			end
		end
	end
	if g.line_on == true then
		-- Draw vertical and horizontal lines
		dbuffer:LineWidth(g.line_width)
		dbuffer:LineStyle(cd.CONTINUOUS)
		dbuffer:Line((s.w/2), s.h, (s.w/2), 0)
		dbuffer:Line(0, (s.h/2), s.w, (s.h/2))
	end
	dbuffer:Flush()
	return iup.DEFAULT
end


function pixel_rgb(image, x, y)
	-- set the background colour to the colour of x,y
	--print("pixel_rgb(image, x, y)", image, x, y)
	local timage = cd.CreateBitmap(image:Width(), image:Height(),cd.RGB)
	local tcanvas = cd.CreateCanvas(cd.IMAGERGB, timage)

	tcanvas:Activate()
	image:cdCanvasPutImageRect(tcanvas, 0, 0, 0, 0, 0, 0, 0, 0)
	local rgb={}
	local t= y*image:Width() + x	-- serialise 2D x,y coords to 1D position in array
	--print("t", t)
	rgb.r= timage.r[t]
	rgb.g= timage.g[t]
	rgb.b= timage.b[t]
	--print("RGB", rgb.r, rgb.g, rgb.b)
	g.bgcolour= encode_colour(rgb)
	tcanvas:Kill()
	cd.KillBitmap(timage)
end



function inimage(lx, ly, mx, my, mw, mh, r)
	-- determine if lx,ly is within the rectangle determined by ll corner mx, my with
	-- width and height mw, mh rotated r degrees
	local click_in_image= false
	local rx= 0
	local ry= 0
	if r == 0 then
			if (lx >= mx and lx <= (mx + mw)) and (ly >= my and ly <= (my + mh)) then
				click_in_image= true
				rx= lx - mx
				ry= ly - my
			end
	else
		local cx= math.floor( mx + mw/2)
		local cy= math.floor( my + mh/2)
		local nx, ny= rotate_point(lx,ly,360 - r,cx,cy)
		--print("nx, mx, mx + mw, ny, my, my + mh", nx, mx, mx + mw, ny, my, my + mh)
		if (nx >= mx and nx <= (mx + mw)) and (ny >= my and ny <= (my + mh)) then
			click_in_image= true
			rx= nx - mx
			ry= ny - my
		end
	end
	return click_in_image, rx, ry
end

function new_ll_corner(rc)
	-- return the x and y of the new lower left corner of the rotated image
	-- it will be the lowest x and y of all of the vertice x and y values
	local nx= rc[0].x
	local ny= rc[0].y
	for i = 1, 3 do
		if rc[i].x < nx then
			nx= rc[i].x
		end
		if rc[i].y < ny then
			ny= rc[i].y
		end
	end

	return nx, ny
end

function new_ur_corner(rc)
	-- return the x and y of the new upper right corner of the rotated image
	-- it will be the highest x and y of all of the vertice x and y values
	local nx= rc[0].x
	local ny= rc[0].y
	for i = 1, 3 do
		if rc[i].x > nx then
			nx= rc[i].x
		end
		if rc[i].y > ny then
			ny= rc[i].y
		end
	end
	return nx, ny
end


function move_rect(rc,dx,dy)
	-- return rectangle with all vertices moved by dx and dy
	local nc= {}
	for i = 0, 3 do
		nc[i]= {}
		nc[i].x= rc[i].x +dx
		nc[i].y= rc[i].y +dy
	end
	return nc
end


function rotate_point(x,y,a,cx,cy)
--print("rotate_point(x,y,a,cx,cy)", x,y,a,cx,cy)
	-- rotate x,y through a degrees counterclockwise around cx, cy
	-- procedure:
	-- bring the degrees of rotation into the range 0 to 360
	-- translate the centre of rotation to 0,0
	-- apply the formula
	-- take the appropriate floor/ceil to be sure to be conservative
	-- floor if >0 otherwise ceil
	-- translate back the centre of rotation to cx, cy
	local ta= a%360 -- also works with negative numbers

	local tx= x - cx
	local ty= y - cy

	local tcos= math.cos(math.rad(ta))
	local tsin= math.sin(math.rad(ta))
	local tnx=(tx * tcos) - (ty * tsin)
	local tny= (tx * tsin) + (ty * tcos)

	local nx, ny
	if tnx > 0 then
		nx= math.floor(tnx)
	else
		nx= math.ceil(tnx)
	end
	if tny > 0 then
		ny= math.floor(tny)
	else
		ny= math.ceil(tny)
	end
	return nx + cx, ny + cy
end


function rotate_vertices(x,y,w,h,a)
--print("rotate_vertices(x,y,w,h,a)", x,y,w,h,a)
	-- return a table with the 4 corners rotated, by a degrees counterclockwise
	-- arouund the centre of the rectangle
	-- with ll corner at x,y
	-- with width w and height h
	-- make the vertices in the sequence ll (lower left),ul,ur,lr
	-- first get the centre of rotation
	local cx= math.floor( x + w/2)
	local cy= math.floor( y + h/2)
	-- then go round the corners rotating each in turn
	local rcorner= {}
	rcorner[0]= {}
	rcorner[0].x, rcorner[0].y = rotate_point(x,y,a,cx,cy)
	rcorner[1]= {}
	rcorner[1].x, rcorner[1].y = rotate_point(x,y+h,a,cx,cy)
	rcorner[2]= {}
	rcorner[2].x, rcorner[2].y = rotate_point(x+w,y+h,a,cx,cy)
	rcorner[3]= {}
	rcorner[3].x, rcorner[3].y = rotate_point(x+w,y,a,cx,cy)
	return rcorner
end




function rotate_degrees(global_image, canvas_image, degrees, x, y, w, h)
	-- take the global image , rotate it degrees and store the rotated image in canvas image
	-- negative because IM rotates clockwise
	local s= math.sin(math.rad(-degrees))
	local c= math.cos(math.rad(-degrees))

	local nwidth, nheight= im.ProcessCalcRotateSize(w, h, c, s)
	local l2image = im.ImageCreate(nwidth, nheight, im.RGB, im.BYTE)
	l2image:AddAlpha()
	local limage= global_image:Duplicate()
	limage:AddAlpha()
	local t= im.ProcessRotate(limage, l2image, c, s, 0)
	canvas_image:Reshape(nwidth, nheight)
	l2image:Copy(canvas_image)
	im.ImageDestroy(limage)
	im.ImageDestroy(l2image)

	-- determine the coords of the rotated corners
	local rc= rotate_vertices(x,y,w,h,degrees)
	local tx, ty= new_ll_corner(rc)
	-- calculate the new ll corner delta of the image and return it, centre point remains the same
	return tx-x, ty-y
end



function cnv:motion_cb(x, y, r)
	--print("cnv:motion_cb(x, y, r, g.md,g.lock_base)", x, y, r, g.md,g.lock_base)
	local ly = self.canvas:UpdateYAxis(y) + s.y
	local lx= x + s.x
	--print(lx, ly)
	if g.md == 1 then
		-- movable image being dragged
		m.x= g.ix + (lx - g.mdx)
		m.y= g.iy + (ly - g.mdy)
		--print("Being dragged, m.x, m.y", m.x, m.y)
		cnv:action(self.posx, self.posy)
	elseif g.md == 2 then
		-- base image being dragged
		b.x= g.ix + (lx - g.mdx)
		b.y= g.iy + (ly - g.mdy)
		--print("Base Being dragged, b.x, b.y", b.x, b.y)
		cnv:action(self.posx, self.posy)
	elseif g.md == 3 then
		-- scrolling by dragging
		--print("scrolling by dragging, s.x, s.y, lx, ly, g.mdx, g.mdy", s.x, s.y, lx, ly, g.mdx, g.mdy)

		self.posx= self.posx - (lx - g.mdx)
		self.posy= self.posy + (ly - g.mdy)
		s.x= math.floor(self.posx)
		s.y= cnv.ymax - math.floor(self.posy)
		--print("scrolling by dragging, s.x, s.y", s.x, s.y)
		cnv:action(self.posx, self.posy)
	  end
  return iup.DEFAULT
end

function cnv:button_cb(but, pressed, x, y, status)
	--print("cnv:button_cb(but, pressed, x, y, status)",but, pressed, x, y, status)
	local ly = self.canvas:UpdateYAxis(y) + s.y
	local lx= x + s.x
	--print("butcnv:action(s.x, s.y), pressed, lx, ly, status, m.x, m.x + m.w, m.y, m.y + m.h", but, pressed, lx, ly, status, m.x, m.x + m.w, m.y, m.y + m.h)
	--print("button pressed", "x", x, "y", y, "lx", lx, "ly", ly, "posx", posx, "posy", posy)
	if but == iup.BUTTON1 and pressed == 1 then
		--print("g.image_avail, g.lock_base", g.image_avail, g.lock_base)
		if g.image_avail == true and inimage(lx, ly, m.x, m.y, m.w, m.h, g.rotate) then
			-- drag the movable image
			--print("movable inside")
			g.md= 1 -- global mouse drag of the moveable image
			g.ix= m.x -- global x of image drag started
			g.iy= m.y -- global y of image drag started
			g.mdx= lx -- global x of where the mouse drag started
			g.mdy= ly -- global y of where the mouse drag started
			self.canvas:SetAttribute("cursor","NONE")
		elseif g.image_avail == false and g.lock_base == false and inimage(lx, ly, b.x, b.y, b.w, b.h, g.base_rotate) then
			-- drag the base image
			--print("base almost inside")
			--if (lx >= b.x and lx <= (b.x + b.w)) and (ly >= b.y and ly <= (b.y + b.h)) then
			--print("base inside")
			g.md= 2 -- global mouse drag of the base image
			g.ix= b.x -- global x of image drag started
			g.iy= b.y -- global y of image drag started
			g.mdx= lx -- global x of where the mouse drag started
			g.mdy= ly -- global y of where the mouse drag started
			self.canvas:SetAttribute("cursor","NONE")
		else
			-- scroll by dragging
			--print("scroll")
			g.md= 3 -- global mouse drag for scroll
			g.mdx= lx -- global x of where the mouse drag started
			g.mdy= ly -- global y of where the mouse drag started
			self.canvas:SetAttribute("cursor","NONE")
		end
	elseif but == iup.BUTTON1 and pressed == 0 then
		g.md= 0 -- global mouse drag of the image
		self.canvas:SetAttribute("cursor","ARROW")
	elseif but ==iup.BUTTON2 and pressed == 1 then
		if g.image_avail == true and g.moveable_image_over == true then
			item_over.value= "OFF"
			item_under.value= "ON"
			g.moveable_image_over= false
			b.image:SetAlpha(g.alpha)
			m.image:SetAlpha(g.max_alpha)
			g.image:SetAlpha(g.max_alpha)
		else
			item_over.value= "ON"
			item_under.value= "OFF"
			g.moveable_image_over= true
			b.image:SetAlpha(g.max_alpha)
			g.baseimage:SetAlpha(g.max_alpha)
			m.image:SetAlpha(g.alpha)
		end
	elseif but ==iup.BUTTON3 and pressed == 1 then
		--print("lx, ly", lx, ly)
		local in_base, bx, by= inimage(lx, ly, b.x, b.y, b.w, b.h, g.base_rotate)
		--print("bx, by", bx, by)
		if g.image_avail == true then
			-- there is a moveable image and a base image
			local in_moveable, mx, my= inimage(lx, ly, m.x, m.y, m.w, m.h, g.rotate)
			--print("mx, my", mx, my)
			if in_moveable == true and in_base == false then
				-- mouse has clicked over moveable image only
				pixel_rgb(g.image, mx, my)
			elseif in_moveable == false and in_base == true then
				-- mouse has clicked over base image only
				pixel_rgb(g.baseimage, bx, by)
			elseif in_moveable == false and in_base == false then
				-- mouse has clicked over neither image
				iup.Alarm("Stitcher - Set Background Colour", "Not pointing at an image" ,"OK")
			else
				-- in_moveable == true and in_base == true then
				-- mouse has clicked over both overlapped images
				if g.moveable_image_over == true then
					-- moveable image is over the base image
					pixel_rgb(g.image, mx, my)
				else
					-- base image is over the moveable image
					pixel_rgb(g.baseimage, bx, by)
				end
			end
		else
			-- there is no moveable image only a base image
			if in_base == true then
				-- mouse has clicked over the base image
				pixel_rgb(g.baseimage, bx, by)
			else
				-- mouse has not clicked over the base image
				iup.Alarm("Stitcher - Set Background Colour", "Not pointing at an image" ,"OK")
			end
		end
	end
	cnv:action(cnv.posx, cnv.posy)
	return iup.DEFAULT
end


function cnv:keypress_cb(c, p)
	--print("cnv:keypress_cb(c, p)",c, p)
	--local posy = cnv.canvas:UpdateYAxis(cnv.posy)
  --print(c, p)
		--print(iup.isCtrlXkey(c))
		if p == 1 and iup.isCtrlXkey(c) == false then -- when key is pressed
			if c == iup.K_s and g.image_avail == true then -- when s is pressed flash
				g.flash= true
				cnv:action(cnv.posx, cnv.posy)


			elseif c == iup.K_j then -- when j is pressed join
				item_join:action()

			elseif c == iup.K_m then -- when m is pressed rotate  clockwise
				-- rotate default degrees clockwise (hence minus)
				if g.lock_base == true then
					if g.image_avail == true then
						g.rotate= g.rotate - g.rotate_step
						m.dx, m.dy= rotate_degrees(g.image, m.image, g.rotate, m.x, m.y, m.w, m.h)
					end
				else
					g.base_rotate= g.base_rotate - g.rotate_step
					b.dx, b.dy= rotate_degrees(g.baseimage, b.image, g.base_rotate, b.x, b.y, b.w, b.h)
				end
				cnv:action(cnv.posx, cnv.posy)


			elseif c == iup.K_b then -- when b is pressed rotate anticlockwise
				-- rotate 1 degree anticlockwise
				if g.lock_base == true then
					if g.image_avail == true then
						g.rotate= g.rotate + g.rotate_step
						m.dx, m.dy= rotate_degrees(g.image, m.image, g.rotate, m.x, m.y, m.w, m.h)
					end
				else
					g.base_rotate= g.base_rotate + g.rotate_step
					b.dx, b.dy= rotate_degrees(g.baseimage, b.image, g.base_rotate, b.x, b.y, b.w, b.h)
				end
				cnv:action(cnv.posx, cnv.posy)


			elseif c == iup.K_n then -- when n is pressed rotate to 0 degree
				-- rotate 1 degree clockwise
				if g.lock_base == true then
					g.rotate= 0
					m.dx, m.dy= rotate_degrees(g.image, m.image, g.rotate, m.x, m.y, m.w, m.h)
				else
					g.base_rotate= 0
					b.dx, b.dy= rotate_degrees(g.baseimage, b.image, g.base_rotate, b.x, b.y, b.w, b.h)
				end
				cnv:action(cnv.posx, cnv.posy)
			elseif g.image_avail == true and (c == iup.K_w or c == iup.K_x or c == iup.K_a or c == iup.K_d or c == iup.K_q or c == iup.K_e or c == iup.K_z or c == iup.K_c) then
				-- key awdx is pressed
				if c == iup.K_w then -- when w is pressed go N
					m.y= m.y+1
				elseif c == iup.K_x then -- when x is pressed go S
					m.y= m.y-1
				elseif c == iup.K_a then -- when a is pressed go W
					m.x= m.x-1
				elseif c == iup.K_d then -- when d is pressed go E
					m.x= m.x+1
				elseif c == iup.K_q then -- when q is pressed go NW
					m.x= m.x-1
					m.y= m.y+1
				elseif c == iup.K_e then -- when e is pressed go NE
					m.x= m.x+1
					m.y= m.y+1
				elseif c == iup.K_z then -- when z is pressed go SW
					m.x= m.x-1
					m.y= m.y-1
				elseif c == iup.K_c then -- when c is pressed go SE
					m.x= m.x+1
					m.y= m.y-1
				end
				cnv:action(cnv.posx, cnv.posy)
			else -- someother key
			--cnv:action(cnv.posx, cnv.posy)
			end
		elseif p == 1 and iup.isCtrlXkey(c) == true then
			--print(c, p)
			--print(iup.isCtrlXkey(c), iup.K_cV)

			if c == iup.K_cV then
				item_paste:action()
			elseif c == iup.K_cC then
				item_copy:action()
			end
		else -- when key is released
			if c == iup.K_s and g.image_avail == true then
				g.flash= false
				cnv:action(cnv.posx, cnv.posy)
			end
		end

  return iup.DEFAULT
end


function cnv:resize_cb(w, h)
	--print("cnv:resize_cb(w, h)",w, h)
	--print("resize_cb", w, h, self.posx, self.posy, self.dx, self.dy)
	s.w = tonumber(w)
	s.h = tonumber(h)
	return iup.DEFAULT
end

function cnv:scroll_cb(op, posx, posy)
--print("cnv:scroll_cb(op, posx, posy)",op, posx, posy, cnv.posx, cnv.posy)
		s.x= math.floor(posx)
		s.y= cnv.ymax - math.floor(posy)
		cnv:action(s.x, s.y)
	return iup.DEFAULT
end


function colour_to_string(lud_colour)
	-- takes a light user data colour for CD  and returns a string of a table with r,g,b values
	local r,g,b= cd.DecodeColor(lud_colour)
	return "{r=" .. r ..",g=" .. g .. ",b=" .. b .. "}"
end

function boolean_to_string(b)
	local bs
	if b == false then
		bs= "false"
	else
		bs= "true"
	end
	return bs
end


function save_env(envfile)
	--print("save_env(envfile)",envfile)
	local sename= default.env_name
	local f= io.open(envfile, "w")
	f:write(sename .. ".dir= [[" .. g.dir .. "]]\n")
	f:write(sename .. ".bgcolour= " .. colour_to_string(g.bgcolour) .. "\n")
	f:write(sename .. ".alpha= " .. g.alpha .. "\n")
	f:write(sename .. ".alpha_step= " .. g.alpha_step .. "\n")
	f:write(sename .. ".min_alpha= " .. g.min_alpha .. "\n")
	f:write(sename .. ".tmpdir= [[" .. g.tmpdir .. "]]\n")
	f:write(sename .. ".tmpname= [[" .. g.tmpname .. "]]\n")
	f:write(sename .. ".tmpsuffix= [[" .. g.tmpsuffix .. "]]\n")
	f:write(sename .. ".line_width= " .. g.line_width .. "\n")
	f:write(sename .. ".fgcolour= " .. colour_to_string(g.fgcolour) .. "\n")
	f:write(sename .. ".virtual_w= "..g.virtual_w .. "\n")
	f:write(sename .. ".virtual_h= "..g.virtual_h .. "\n")
	f:write(sename .. ".virtual_step= "..g.virtual_step .. "\n")
	f:write(sename .. ".window_w= "..g.window_w .. "\n")
	f:write(sename .. ".window_h= "..g.window_h .. "\n")
	f:write(sename .. ".virtual_sx= "..g.virtual_sx .. "\n")
	f:write(sename .. ".virtual_sy= "..g.virtual_sy .. "\n")
	f:write(sename .. ".edge= "..g.edge .. "\n")
	f:write(sename .. ".rotate_step= "..g.rotate_step .. "\n")
	f:write(sename .. ".pastename= ".. g.pastename .. "\n")
	f:write(sename .. ".paste_save= ".. boolean_to_string(g.paste_save) .. "\n")
	f:write(sename .. ".history= "..boolean_to_string(g.history) .. "\n")
	f:close()
end



dlg = iup.dialog{cnv, title="Simple Stitcher", menu=menu}



function dlg:close_cb()
	--print("dlg:close_cb()")
	save_env(default.env_file)
	if m.image then
		m.image:Destroy()
	end
	if g.image then
		g.image:Destroy()
	end
	if g.baseimage then
		g.baseimage:Destroy()
	end
	if b.image then
		b.image:Destroy()
	end

	cnv.canvas:Kill()
	cnv.dbuffer:Kill()
	iup.Destroy(g.clipboard)
	self:destroy()
	iup.ExitLoop()
	return iup.IGNORE -- because we destroy the dialog
end


dlg:show()
--iup.MainLoop()
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
end

--print("CD canvas size", cnv:cdCanvasGetSize())
--local counter
--local return_value
--counter= 0
--print("Start main Loop")
--return_value= iup.LoopStepWait()
--while return_value ~= iup.CLOSE do
	-- update reactors
	--print("Main Loop counter = ", counter)
--	counter= counter + 1
--	return_value= iup.LoopStepWait()
--end
--print("Clean end")

