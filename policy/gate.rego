package edm.engine.gate

# BDD-first gate: specs precede implementation, render stays untested I/O.
# Run: opa eval -i input.json -d policy/gate.rego "data.edm.engine.gate.deny"

deny contains msg if {
	not input.files["t/package.lisp"]
	msg := "missing t/package.lisp: no FiveAM suite defined"
}

deny contains msg if {
	some path
	src := input.files[path]
	startswith(path, "src/")
	not contains(path, "render")
	not contains(path, "package")
	spec_path := sprintf("t/%s-spec.lisp", [trim_prefix(trim_suffix(path, ".lisp"), "src/")])
	not input.files[spec_path]
	msg := sprintf("%s has no matching FiveAM spec (render.lisp is the only exempt I/O boundary)", [path])
}

deny contains msg if {
	not input.files["CHANGELOG.md"]
	msg := "missing CHANGELOG.md"
}

deny contains msg if {
	not input.files["LICENSE"]
	msg := "missing LICENSE"
}

deny contains msg if {
	some path
	src := input.files[path]
	startswith(path, "src/")
	not contains(src, "(declaim (optimize")
	msg := sprintf("%s missing (declaim (optimize ...)) — dps-meta Qlot convention requires speed/safety declaims in hot paths", [path])
}
