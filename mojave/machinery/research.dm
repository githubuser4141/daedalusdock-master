// Machine sprites sourced from Shiptest under AGPL-3.0:
// https://github.com/shiptest-ss13/Shiptest/blob/master/icons/obj/machines/research.dmi

/obj/machinery/rnd/production/protolathe
	name = "protolathe"
	desc = "Converts raw materials into useful objects from designs stored on a data disk."
	icon = 'mojave/icons/obj/machines/research_shiptest.dmi'
	icon_state = "protolathe"
	circuit = /obj/item/circuitboard/machine/protolathe
	allowed_buildtypes = FABRICATOR
	zmm_flags = ZMM_MANGLE_PLANES

/obj/machinery/rnd/production/protolathe/user_try_print_id(id, amount)
	. = ..()
	if(.)
		flick("protolathe_n", src)

/obj/machinery/rnd/production/circuit_imprinter/ms13
	icon = 'mojave/icons/obj/machines/research_shiptest.dmi'
	circuit = /obj/item/circuitboard/machine/circuit_imprinter/ms13

/obj/machinery/rnd/destructive_analyzer/ms13
	icon = 'mojave/icons/obj/machines/research_shiptest.dmi'
	circuit = /obj/item/circuitboard/machine/destructive_analyzer/ms13

// DD's research machines manage their own data disks, so this is the department monitor terminal.
/obj/machinery/computer/rdconsole
	parent_type = /obj/machinery/computer/security/research
	name = "R&D console"
	desc = "A research workstation connected to the R&D camera network. Fabricators and analyzers are operated directly."
	icon_screen = "rdcomp"
	icon_keyboard = "rd_key"
	circuit = /obj/item/circuitboard/computer/rdconsole

/obj/machinery/computer/security/ms13
	desc = "A security workstation connected to the local camera network."
	circuit = /obj/item/circuitboard/computer/security/ms13

/obj/item/circuitboard/machine/protolathe
	parent_type = /obj/item/circuitboard/machine/fabricator
	name = "Protolathe (Machine Board)"
	build_path = /obj/machinery/rnd/production/protolathe

/obj/item/circuitboard/machine/circuit_imprinter/ms13
	name = "Circuit Imprinter (Machine Board)"
	build_path = /obj/machinery/rnd/production/circuit_imprinter/ms13

/obj/item/circuitboard/machine/destructive_analyzer/ms13
	name = "Destructive Analyzer (Machine Board)"
	build_path = /obj/machinery/rnd/destructive_analyzer/ms13

/obj/item/circuitboard/computer/rdconsole
	parent_type = /obj/item/circuitboard/computer/research
	name = "R&D Console (Computer Board)"
	build_path = /obj/machinery/computer/rdconsole

/obj/item/circuitboard/computer/security/ms13
	name = "Security Cameras (Computer Board)"
	build_path = /obj/machinery/computer/security/ms13
