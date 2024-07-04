set simmulator "vcs"

set waves "none"
if {[info exists ::env(WAVES)]} {
  set waves "$::env(WAVES)"
}

set gui 0
if {[info exists ::env(GUI)]} {
  set gui "$::env(GUI)"
}

set tb_top "tb"
if {[info exists ::env(TB_TOP)]} {
  set tb_top "$::env(TB_TOP)"
} else {
  puts "WARNING: TB_TOP environment variable not set - using \"tb\" as the
        top level testbench hierarchy."
}

proc setDefault {var value} {
  upvar $var var_
  if {[info exists var_]} {
    puts "INFO: \"$var\" is already set to \"$var_\"."
  } else {
    puts "INFO: Setting \"$var\" to \"$value\"."
    set var_ $value
  }
  return $var_
}

proc wavedumpScope {waves simulator scope {depth 0} {fsdb_flags "+all"} {probe_flags "-all"}
                    {dump_flags "-aggregates"}} {

  switch $waves {
    "none" {
      return
    }

    "fsdb" {
      fsdbDumpvars $depth $scope $fsdb_flags
      fsdbDumpSVA $depth $scope
    }

    "shm" {
      if {$depth == 0} {
        set depth "all"
      }
      probe "$scope" $probe_flags -depth $depth -memories -shm
    }

    "vpd" {
      global vpd_fid
      dump -add "$scope" -fid $vpd_fid -depth $depth $dump_flags
    }

    default {
      puts "ERROR: Unknown wave format: ${waves}."
      quit
    }
  }

  puts "INFO: Dumping waves in scope \"$scope:$depth\"."
}

setDefault vpd_fid 0

if {$waves ne "none"} {
  set wavedump_db "waves.$waves"
  puts "INFO: Dumping waves in [string toupper $waves] format to $wavedump_db."

  switch $waves {
    "fsdb" {
      fsdbDumpfile $wavedump_db
    }

    "vpd" {
      global vpd_fid
      set vpd_fid [dump -file $wavedump_db -type VPD]
    }

    default {
      puts "ERROR: Unknown wave format: ${waves}."
      quit
    }
  }

  setDefault dump_tb_top 1

  if {$dump_tb_top == 1} {
    wavedumpScope $waves $simulator $tb_top 0
  } else {
    puts "INFO: the hierarchies to be dumped are expected to be indicated externally."
  }
}

if {$gui == 0} {
  run
  quit
}
