(
local gen_gcode,gen_spline

fn relocateObj spl =
(
	if gen_spline.obj_reallocate.checked then(
	spl.pos	= spl.pos - spl.min
	)
)

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
		splinesize				 = gen_spline.target_object.object.max-gen_spline.target_object.object.min
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
	relocateObj spl

	stepsx			= Cieling  ((spl.max[1]-spl.min[1])/RouterDiameter)
	stepsy			= Cieling  ((spl.max[2]-spl.min[2])/RouterDiameter)
	flag			= 1
	splineCounter		= 1
	result			= SplineShape wirecolor:SplineColor name:SplineName 

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

fn DoRefineSpline spl segLen=
(
	if spl!=undefined then
	(
		convertToSplineShape spl

		for s = 1 to (numsplines spl) do(
			curSeg	 = 1
			totalSeg = (numknots spl s)
			for k = 1 to totalSeg do(
				p1	= getKnotPoint spl s (curSeg  )
				p2	= [0,0,0]
				if (k==totalSeg) then(
					addSeg	= 1
					if (isClosed spl s) then(
						p2	= getKnotPoint spl s 1
						MyRad	= ((p2[1]-p1[1])^2 + (p2[2]-p1[2])^2)^0.5
						addSeg	= Cieling (MyRad/segLen)
					)
				)else(
					p2	= getKnotPoint spl s (curSeg+1)
					MyRad	= ((p2[1]-p1[1])^2 + (p2[2]-p1[2])^2)^0.5
					addSeg	= Cieling (MyRad/segLen)
				)
				if addSeg>1 then(
					subdivideSegment spl s curSeg addSeg
					curSeg+=(1+addSeg)
				)
			)
		)
		updateShape spl
	)
)

fn DoGCode spl FileName=
(
	relocateObj spl

	MySize		= spl.max - spl.min
	OldZ		= 0
	laserFlag	= 0
	out_file 	= createfile FileName

	format "G90 G21 \n" 	to:out_file		-- G91: Exact Mod, G21: mm
	format "G1 F%\n" 	gen_gcode.feedback_rate.value to:out_file		-- G1: move with feed rate xx
	format "G52 G0 Z0 \n" 	to:out_file
	format "G0 X0 Y0 Z0 \n" to:out_file
	
	for s = 1 to (numsplines spl) do(
		for k = 1 to (numknots spl s) do(
			gen_gcode.prog_savefile.value=100*k/(numknots spl s)
			MyX=(getKnotPoint spl s k).x
			MyY=(getKnotPoint spl s k).y
			MyZ=(getKnotPoint spl s k).z
			MyZ=gen_gcode.laser_min.value+((gen_gcode.laser_max.value-gen_gcode.laser_min.value)*(MySize[3]-MyZ)/MySize[3]) as integer

--			MyX=(int(10000*MyX) as float)/10000
--			MyY=(int(10000*MyY) as float)/10000
--			MyZ=(int(10000*MyZ) as float)/10000
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
	
	format "M5 \n" 		to:out_file
	format "G52 G0 Z0 \n" 	to:out_file
	format "G0 X0 Y0 Z0 \n" to:out_file
	
	close out_file
	gen_gcode.prog_savefile.value=0
)

rollout gen_spline "3D Spline"
(
	edittext prefix_txt "Name:" fieldWidth:100 labelOnTop:false pos:[5,10,0] tooltip: "Generated Spline Name"
	colorpicker prefix_color "" color:[0,0,255] modal:false width:20 height:18 tooltip: "Generated Spline Color"  pos:[140,10,0] 
	spinner driller_size "Laser size:" range:[.1,20,.2] type:#float width:170 pos:[-10,35,0]
	checkbox obj_reallocate "Object Reallocation" checked:false tooltip:"Move object to [0,0,0]"
	pickbutton target_object "Pick Object" width:140 filter:pickobj tooltip: "3D Object used to project spline on"
	label obj_size "Size (mm): N/A" style_sunkenedge:true width:190 height:16
	radiobuttons mesh_type labels:#("X-Only", "Y-Only") columns:2 default:1 tooltip: "Generated Spline Path Type" pos:[5,120,0]
	button generate_spline_btn "Generate Spline" enabled:false tooltip: "You have to pick the 3d object and enter object name"
	progressbar prog_genspline color:red

	on target_object picked obj do
	(
		if obj != undefined do
		(
			select obj
			relocateObj obj
			target_object.text	 = obj.name
			obj_size.text		 = "Size (mm): "
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
--		ref_spline.ref_spline_object.object = DoMesh target_object.object driller_size.value prefix_txt.text prefix_color.color gen_spline.mesh_type.state
--		ref_spline.ref_spline_object.text   = ref_spline.ref_spline_object.object.name

		gen_gcode.spline_object.object = DoMesh target_object.object driller_size.value prefix_txt.text prefix_color.color gen_spline.mesh_type.state
		gen_gcode.spline_object.text=gen_gcode.spline_object.object.name
		refresh_value()
	)
)

rollout ref_spline "Refine Spline"
(
	pickbutton ref_spline_object "Pick Spline" width:140 filter:pickspline tooltip: "Spline to be refined"
	button generate_refine_btn "Refine Spline" enabled:false tooltip: "You have to pick the spline"
	progressbar prog_refinespline color:red
	
	on ref_spline_object picked obj do
	(
		if obj != undefined then
		(
			select obj
			relocateObj obj
			ref_spline_object.text	= obj.name
			ref_spline.generate_refine_btn.enabled	= true
		)else(
			ref_spline.generate_refine_btn.enabled	= false
		)
	)
	on generate_refine_btn pressed do
	(
		DoRefineSpline ref_spline_object.object (10*gen_spline.driller_size.value)
	)
)

rollout gen_gcode "Generate GCode"
(
	pickbutton spline_object "Pick Spline" width:140 filter:pickspline tooltip: "Spline to be converted in GCode"
	edittext gcode_filename "File Name:" fieldWidth:90 labelOnTop:false tooltip: "Generated GCode file name"
	group "Options"
	(
	spinner feedback_rate "Move speed:" range:[50,2000,100] type:#integer width:140 
	spinner laser_max "Laser high:" range:[1000,15000,10000] type:#integer width:140 
	spinner laser_min "Laser low:" range:[100,8000,3000] type:#integer width:140 
	)
	button generate_gcode_btn "Generate GCode" enabled:false tooltip: "Youhave to pick the spline"
	progressbar prog_savefile color:red
	
	on spline_object picked obj do
	(
		if obj != undefined do
		(
			select obj
			relocateObj obj
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
addrollout ref_spline CNCFloater rolledUp:true
addrollout gen_gcode CNCFloater rolledUp:false

if selection[1]!=undefined then
(
	if (SuperclassOf (selection[1]) as string)=="shape" then 
	(
		relocateObj selection[1]
		gen_gcode.spline_object.object		= selection[1]
		gen_gcode.spline_object.text		= selection[1].name

		ref_spline.ref_spline_object.object	= selection[1]
		ref_spline.ref_spline_object.text	= selection[1].name
		ref_spline.generate_refine_btn.enabled	= true
	)else(
		mysize=selection[1].max-selection[1].min
		if mysize[1]!=0 and mysize[2]!=0 and mysize[3]!=0 then 
		(
			relocateObj selection[1]
			gen_spline.target_object.object	= selection[1]
			gen_spline.target_object.text	= selection[1].name
		)
	)
)
refresh_value()

)