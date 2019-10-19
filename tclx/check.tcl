
proc packages {{pattern *}} {
        catch {package require ""}
        set res {}
        foreach p [lsort [package names]] {
                if [string match $pattern $p] {
                        lappend res $p [package versions $p]
                }
        }
        set res
}


foreach {p v} [packages T*] {puts "$p : $v"}

