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
		gen_spline.obj_size.text		+= ","
		gen_spline.obj_size.text		+= (int(10*splinesize[2]) as float /10) as string 
		gen_spline.obj_size.text		+= ","
		gen_spline.obj_size.text		+= (int(10*splinesize[3]) as float /10) as string 
	)
)


fn DoMesh spl RouterDiameter SplineName SplineColor Options=
(
	spl.pos		= spl.pos - spl.min
	stepsx		= Cieling  ((spl.max[1]-spl.min[1])/RouterDiameter)
	stepsy		= Cieling  ((spl.max[2]-spl.min[2])/RouterDiameter)
	flag		= 1
	splineCounter	= 1
	result		= SplineShape wirecolor:SplineColor name:SplineName 

	addNewSpline result

	if Options==1 then 
	(
		for y=0 to stepsy do
		(
			oldPos	= [-1,-1,-1]
			flag	= -flag
			gen_spline.prog_genspline.value=y*100/stepsy
			for x=0 to stepsx do
			(
				MypntX	= spl.min[1]+(x*RouterDiameter)
				MypntY	= spl.min[2]+(y*RouterDiameter)
				MypntZ	= spl.min[3]
	
				if flag==1 then MypntX=spl.min[1]+spl.max[1]-MypntX

				tmp	= intersectray spl (ray [MypntX,MypntY,spl.max[3]+10] [0,0,-1])
				if tmp != undefined then MypntZ	= tmp.pos.z
				MypntZ	= int(1000*MypntZ)/1000

				if MypntZ!=0 then(
					if oldPos[3]!=MypntZ or x==stepsx then(
						addKnot result splineCounter #corner #line [MypntX,MypntY,MypntZ]
					)
				)else(
					if oldPos[3]>0 then(
						addKnot result splineCounter #corner #line oldPos
						addNewSpline result
						splineCounter=splineCounter+1
					)
				)
				oldPos=[MypntX,MypntY,MypntZ]
			)
		)
		if (numknots result splineCounter)<2 then(
			addKnot result splineCounter #corner #line [0,0,0]
			addKnot result splineCounter #corner #line [0,0,0]
		)
		updateShape result
	)else(
		for x=0 to stepsx do
		(
			oldPos	= [-1,-1,-1]
			flag	= -flag
			gen_spline.prog_genspline.value=x*100/stepsx
			for y=0 to stepsy do
			(
				MypntX	= spl.min[1]+(x*RouterDiameter)
				MypntY	= spl.min[2]+(y*RouterDiameter)
				MypntZ	= spl.min[3]
	
				if flag==1 then MypntY=spl.min[2]+spl.max[2]-MypntY

				tmp	= intersectray spl (ray [MypntX,MypntY,spl.max[3]+10] [0,0,-1])
				if tmp != undefined then MypntZ	= tmp.pos.z
				MypntZ	= int(1000*MypntZ)/1000

				if MypntZ!=0 then(
					if oldPos[3]!=MypntZ or y==stepsy then(
						addKnot result splineCounter #corner #line [MypntX,MypntY,MypntZ]
					)
				)else(
					if oldPos[3]>0 then(
						addKnot result splineCounter #corner #line oldPos
						addNewSpline result
						splineCounter=splineCounter+1
					)
				)
				oldPos=[MypntX,MypntY,MypntZ]
			)
		)
		if (numknots result splineCounter)<2 then(
			addKnot result splineCounter #corner #line [0,0,0]
			addKnot result splineCounter #corner #line [0,0,0]
		)
		updateShape result
	)
	gen_spline.prog_genspline.value=0
	return result
)

fn DoGCode spl FileName=
(
	spl.pos		= spl.pos - spl.min
	MySize		= spl.max - spl.min
	OldZ		= 0
	laserFlag	= 0
	out_file 	= createfile FileName

	format "G90 G21 \n" 	to:out_file		-- G91: Exact Mod, G21: mm
	format "G1 F%\n" 	gen_gcode.feedback_rate.value to:out_file		-- G1: move with feed rate xx
	format "G52 G0 Z0 \n" 	to:out_file
	format "G0 X0 Y0 Z0 \n" to:out_file
	
	for s = 1 to (numsplines spl) do
	(
		for k = 1 to (numknots spl s) do (
			gen_gcode.prog_savefile.value=100*k/(numknots spl s)
			MyX=(getKnotPoint spl s k).x
			MyY=(getKnotPoint spl s k).y
			MyZ=(getKnotPoint spl s k).z
			MyZ=gen_gcode.laser_min.value+((gen_gcode.laser_max.value-gen_gcode.laser_min.value)*(MySize[3]-MyZ)/MySize[3]) as integer
			if (k==1) then  --move to the first point as fast as you can
			(
				format "M5 \n" to:out_file
				format "G0 X% Y% \n" MyX MyY to:out_file
				laserFlag=0
			)else(
		            if abs(OldZ-MyZ)>20 or laserFlag==0 then (
				format "M3 S%\n" MyZ to:out_file
				OldZ=MyZ
				laserFlag=1
			    )
			    if abs(OldZ)>20 then(
				format "G1 X% Y% \n" MyX MyY to:out_file
			    )
			)
			if k==(numknots spl s) and (isClosed spl s) then  --if shape closed then draw line
			(
				MyX=(getKnotPoint spl s 1).x
				MyY=(getKnotPoint spl s 1).y
				MyZ=(getKnotPoint spl s 1).z
				MyZ=gen_gcode.laser_min.value+((gen_gcode.laser_max.value-gen_gcode.laser_min.value)*(MySize[3]-MyZ)/MySize[3]) as integer
				if abs(OldZ-MyZ)>20 then
				(
					format "M3 S%\n" MyZ to:out_file
					OldZ=MyZ
					laserFlag=1
				)
				if abs(OldZ)>20 then
				(
					format "G1 X% Y% \n" MyX MyY to:out_file
				)
			)
		)
	)
	
	format "G52 G0 Z0 \n" 	to:out_file
	format "G0 X0 Y0 Z0 \n" to:out_file
	format "M5 \n" 		to:out_file
	
	close out_file
	gen_gcode.prog_savefile.value=0
)

rollout gen_spline "Generate Spline"
(
	edittext prefix_txt "Name:" fieldWidth:100 labelOnTop:false pos:[5,10,0] tooltip: "Generated Spline Name"
	colorpicker prefix_color "" color:[0,0,255] modal:false width:20 height:18 tooltip: "Generated Spline Color"  pos:[140,10,0] 
	spinner driller_size "Driller size:" range:[.1,20,.2] type:#float width:170 pos:[-10,35,0]
	label obj_size "Size (mm): N/A" style_sunkenedge:true width:190 height:16
	pickbutton target_object "Pick Object" width:140 filter:pickobj tooltip: "3D Object used to project spline on"
	radiobuttons mesh_type labels:#("X-Only", "Y-Only") columns:2 default:1 tooltip: "Generated Spline Path Type" pos:[5,110,0]
	button generate_spline_btn "Generate Spline" enabled:false tooltip: "You have to pick the 3d object and enter object name"
	progressbar prog_genspline color:red

	on target_object picked obj do
	(
		if obj != undefined do
		(
			select obj
			obj.pos				 = obj.pos - obj.min
			target_object.text	 = obj.name
			obj_size.text		 = "Size (mm): "
			obj_size.text		+= (int(10*(obj.max-obj.min)[1]) as float /10) as string 
			obj_size.text		+= ","
			obj_size.text		+= (int(10*(obj.max-obj.min)[2]) as float /10) as string 
			obj_size.text		+= ","
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
	group "Options"
	(
	spinner feedback_rate "Move speed:" range:[50,2000,100] type:#integer width:140 
	spinner laser_max "Laser high:" range:[5000,15000,10000] type:#integer width:140 
	spinner laser_min "Laser low:" range:[1000,8000,3000] type:#integer width:140 
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
		DoGCode spline_object.object gcode_filename.text 
	)
)


CNCFloater = newrolloutfloater "T-CNC (Laser)" 200 430
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
