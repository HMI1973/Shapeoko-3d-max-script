(
local gen_gcode,gen_spline

fn GetSplineNewName =
(
	for x=1 to 100 do
	(
		new_objname 	 = "CNCSpline"
		if x<10 then new_objname +="0"
		new_objname 	+= x as string
		object_found	 = -1
		For CurrentObject in objects do
		(
			if CurrentObject.name==new_objname then object_found = 1
		)
		if object_found==-1 then return new_objname
	)
)

fn Cieling MyNum=
(
	if MyNum>int(MyNum) then MyNum=int(MyNum)+1
	return MyNum
)

fn pickobj obj = (
	mysize=obj.max-obj.min
	if mysize[1]==0 or mysize[2]==0 or mysize[3]==0 then return false else	return true
)

fn pickspline obj = (
	if (SuperclassOf (obj) as string)=="shape" then return true else return false
)

fn refresh_value = (
	gen_spline.generate_spline_btn.enabled=true
	gen_gcode.generate_gcode_btn.enabled=true
	if gen_spline.prefix_txt.text=="" then gen_spline.prefix_txt.text=GetSplineNewName()
	if gen_gcode.gcode_filename.text=="" then gen_gcode.gcode_filename.text=("d:\\") as string + gen_spline.prefix_txt.text + (".nc") as string
	if gen_spline.target_object.object==undefined then gen_spline.generate_spline_btn.enabled=false
	if gen_gcode.spline_object.object==undefined then gen_gcode.generate_gcode_btn.enabled=false
	if gen_spline.target_object.object!=undefined then 
	(
		splinesize						 = gen_spline.target_object.object.max-gen_spline.target_object.object.min
		gen_spline.obj_size.text		 = "Size (mm): "
		gen_spline.obj_size.text		+= (int(10*splinesize[1]) as float /10) as string 
		gen_spline.obj_size.text		+= " x "
		gen_spline.obj_size.text		+= (int(10*splinesize[2]) as float /10) as string 
		gen_spline.obj_size.text		+= " x "
		gen_spline.obj_size.text		+= (int(10*splinesize[3]) as float /10) as string 
	)
)


fn DoMesh spl RouterDiameter SplineName SplineColor Options=
(
	spl.pos			= spl.pos - spl.min

	stepsx			= Cieling  ((spl.max[1]-spl.min[1])/RouterDiameter)
	stepsy			= Cieling  ((spl.max[2]-spl.min[2])/RouterDiameter)
	flag				= 1
	result			= SplineShape wirecolor:SplineColor name:SplineName 
	percentage		= 50
	
	addNewSpline result

	if Options==1 or Options==2 then percentage	= 100
	if Options==1 or Options==3 then 
	(
		for y=0 to stepsy do
		(
			gen_spline.prog_genspline.value=y*percentage/stepsy
			for x=0 to stepsx do
			(
				MypntX	= spl.min[1]+(x*RouterDiameter)
				MypntY	= spl.min[2]+(y*RouterDiameter)
	
				if flag==-1 then MypntX=spl.min[1]+spl.max[1]-MypntX
		
				if MypntX<=spl.min[1] then MypntX=spl.min[1]
				if MypntX>=spl.max[1] then MypntX=spl.max[1]
				if MypntY<=spl.min[2] then MypntY=spl.min[2]
				if MypntY>=spl.max[2] then MypntY=spl.max[2]
	
				tmp		= intersectray spl (ray [MypntX,MypntY,spl.max[3]+10] [0,0,-1])
				MypntZ	= spl.min[3]
				if tmp!= undefined then MypntZ	= tmp.pos.z
				addKnot result 1 #corner #line [MypntX,MypntY,MypntZ]
			)
			flag=-flag
		)
	)
	flag				= 1
	if Options==2 or Options==3 then 
	(
		for x=0 to stepsx do
		(
			gen_spline.prog_genspline.value=(100-percentage)+(x*percentage/stepsx)
			for y=0 to stepsy do
			(
				MypntX	= spl.min[1]+((stepsx-x)*RouterDiameter)
				MypntY	= spl.min[2]+((stepsy-y)*RouterDiameter)
	
				if flag==-1 then MypntY=spl.min[2]+spl.max[2]-MypntY
		
				if MypntX<spl.min[1] then MypntX=spl.min[1]
				if MypntX>spl.max[1] then MypntX=spl.max[1]
				if MypntY<spl.min[2] then MypntY=spl.min[2]
				if MypntY>spl.max[2] then MypntY=spl.max[2]
	
				tmp		= intersectray spl (ray [MypntX,MypntY,spl.max[3]+10] [0,0,-1])
				MypntZ	= spl.min[3]
				if tmp!= undefined then MypntZ	= tmp.pos.z
				addKnot result 1 #corner #line [MypntX,MypntY,MypntZ]
			)
			flag=-flag
		)
	)

	updateShape result
	gen_spline.prog_genspline.value=0
	return result
)

fn DoGCode spl FileName StepSize=
(
	spl.pos		= spl.pos - spl.min

	MySize		= spl.max-spl.min
	MaxZ		= 1+(MySize[3]/StepSize)
	out_file 	= createfile FileName

	format "G90 G21 \n" to:out_file		-- G91: Exact Mod, G21: mm
	format "M3 S%\n" gen_gcode.spendler_rpm.value to:out_file
	format "G52 G0 Z0 \n" to:out_file
	format "G1 F%\n" gen_gcode.feedback_rate.value to:out_file		-- G1: move with feed rate xx
	format "X0 Y0 Z0 \n" to:out_file
	
	for cz=0 to MaxZ do
	(
		gen_gcode.prog_savefile.value=cz*100/MaxZ
		z=cz*StepSize
		if z>MySize[3] then z=MySize[3]
		for s = 1 to (numsplines spl) do(
			for k = 1 to (numknots spl s) do (
				MyX=(getKnotPoint spl s k).x
				MyY=(getKnotPoint spl s k).y
				MyZ=(getKnotPoint spl s k).z
				MyZ=(MyZ*z/MySize[3])-z
				if (k==1) then --first point then move to safe z first
				(
					format "G0 Z0 \n" to:out_file
					format "G0 X% Y% \n" MyX MyY to:out_file
					format "G1 Z% \n" MyZ to:out_file
				)else(
					format "G1 X% Y% Z%\n" MyX MyY MyZ  to:out_file
				)
			)
		)
	)
	
	format "G52 G0 Z0 \n" to:out_file
	format "G1 X0 Y0 Z0 \n" to:out_file
	format "M5 \n" to:out_file
	
	close out_file
	gen_gcode.prog_savefile.value=0
)

rollout gen_spline "Generate Spline"
(
	edittext prefix_txt "Name:" fieldWidth:100 labelOnTop:false pos:[5,10,0] tooltip: "Generated Spline Name"
	colorpicker prefix_color "" color:[0,0,255] modal:false width:20 height:18 tooltip: "Generated Spline Color"  pos:[140,10,0] 
	spinner driller_size "Driller size:" range:[.1,20,3] type:#float width:170 pos:[-10,35,0]
	label obj_size "Size (mm): N/A" style_sunkenedge:true width:190 height:16
	pickbutton target_object "Pick Object" width:140 filter:pickobj tooltip: "3D Object used to project spline on"
	radiobuttons mesh_type labels:#("X-Only", "Y-Only", "Both X and Y") columns:2 default:3 tooltip: "Generated Spline Path Type" pos:[5,110,0]
	button generate_spline_btn "Generate Spline" enabled:false tooltip: "You have to pick the 3d object and enter object name"
	progressbar prog_genspline color:red

	on target_object picked obj do
	(
		if obj != undefined do
		(
			select obj
			obj.pos			  = obj.pos - obj.min
			target_object.text	  = obj.name
			obj_size.text		  = "Size (mm): "
			obj_size.text		+= (int(10*(obj.max-obj.min)[1]) as float /10) as string 
			obj_size.text		+= " x "
			obj_size.text		+= (int(10*(obj.max-obj.min)[2]) as float /10) as string 
			obj_size.text		+= " x "
			obj_size.text		+= (int(10*(obj.max-obj.min)[3]) as float /10) as string 
		)
		refresh_value()
	)
	on prefix_txt entered txt do
	(
		refresh_value()
	)

	on generate_spline_btn pressed do
	(
		gen_gcode.spline_object.object = DoMesh target_object.object driller_size.value prefix_txt.text prefix_color.color gen_spline.mesh_type.state
		gen_gcode.spline_object.text=gen_gcode.spline_object.object.name
		refresh_value()
	)
)

rollout gen_gcode "Generate GCode"
(
	pickbutton spline_object "Pick Spline" width:140 filter:pickspline tooltip: "Spline to be converted in GCode"
	edittext gcode_filename "File Name:" fieldWidth:90 labelOnTop:false tooltip: "Generated GCode file name"
	spinner step_size "Z Step :" range:[.1,5,.5] type:#float width:150 pos:[5,60,0]
	group "Options"
	(
	spinner feedback_rate "Move speed:" range:[50,2000,500] type:#integer width:140 
	spinner spendler_rpm "Driller speed:" range:[1000,20000,8000] type:#integer width:140 
	)
	button generate_gcode_btn "Generate GCode" enabled:false tooltip: "Youhave to pick the spline"
	progressbar prog_savefile color:red
	
	on spline_object picked obj do
	(
		if obj != undefined do
		(
			select obj
			obj.pos				= obj.pos - obj.min
			spline_object.text	= obj.name
		)
		refresh_value()
	)
	on gcode_filename entered txt do
	(
		refresh_value()
	)

	on generate_gcode_btn  pressed do
	(
		DoGCode spline_object.object gcode_filename.text step_size.value
	)
)


CNCFloater = newrolloutfloater "T-CNC (Milling)" 200 500
addrollout gen_spline CNCFloater rolledUp:false
addrollout gen_gcode CNCFloater rolledUp:false

if selection[1]!=undefined then
(
	if (SuperclassOf (selection[1]) as string)=="shape" then 
	(
		selection[1].pos				= selection[1].pos - selection[1].min
		gen_gcode.spline_object.object	= selection[1]
		gen_gcode.spline_object.text	= selection[1].name
	)else(
		mysize=selection[1].max-selection[1].min
		if mysize[1]!=0 and mysize[2]!=0 and mysize[3]!=0 then 
		(
			selection[1].pos				= selection[1].pos - selection[1].min
			gen_spline.target_object.object	= selection[1]
			gen_spline.target_object.text	= selection[1].name
		)
	)
)
refresh_value()

)