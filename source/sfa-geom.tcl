# tolType = 1 for non-geometric tolerance (dimension, datum target, annotations)
proc getAssocGeom {entDef {tolType 0} {tolName ""}} {
  global opt syntaxErr

  set entDefType [$entDef Type]
  if {$opt(debugAG)} {outputMsg "\ngetAssocGeom $tolType $entDefType [$entDef P21ID]" blue}

  set dimSize 0
  if {$tolType == 2} {
    set tolType 1
    set dimSize 1
  }

  if {[catch {
    if {$entDefType == "shape_aspect" || $entDefType == "all_around_shape_aspect" || $entDefType == "centre_of_symmetry" || $entDefType == "geometric_alignment" || \
      ([string first "datum" $entDefType] != -1 && [string first "_and_" $entDefType] == -1)} {

# add shape_aspect to AG for dimtol (tolType = 1)
      if {$tolType && ($entDefType == "shape_aspect" || $entDefType == "centre_of_symmetry" || $entDefType == "geometric_alignment" || \
                       $entDefType == "datum_feature" || [string first "datum_target" $entDefType] != -1)} {
        set type [appendAssocGeom $entDef A]

# for dimensional_size, check applies_to > shape_aspect > product_definitional attribute
        if {$dimSize} {checkShapeAspect $entDef}
      }

# find datum_feature for datum
      if {$entDefType == "datum"} {
        set e0s [$entDef GetUsedIn [string trim shape_aspect_relationship] [string trim related_shape_aspect]]
        ::tcom::foreach e0 $e0s {
          if {[string first "relationship" [$e0 Type]] != -1} {
            ::tcom::foreach a0 [$e0 Attributes] {
              if {[$a0 Name] == "relating_shape_aspect"} {
                if {[[$a0 Value] Type] == "datum_feature"} {set entDef [$a0 Value]}
              }
            }
          }
        }
      }

# find AF for SA with GISU or IIRU
      getAssocGeomFace $entDef $tolType
    }

# look at SAR with CSA, CGSA, AASA, COS to find SAs, possibly nested
    if {$opt(debugAG)} {outputMsg " $entDefType [$entDef P21ID] D" red}
    set type [appendAssocGeom $entDef D]
    set e0s [$entDef GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
    ::tcom::foreach e0 $e0s {
      if {[string first "relationship" [$e0 Type]] != -1} {
        ::tcom::foreach a0 [$e0 Attributes] {
          if {[$a0 Name] == "related_shape_aspect"} {
            catch {unset relatedSA}
            if {[catch {
              set relatedSA [[$a0 Value] Type]
              set a00 $a0

# check for component_path_shape_aspect as related
              if {$relatedSA == "component_path_shape_aspect"} {
                appendAssocGeom [$a0 Value]
                set a00 [[[$a0 Value] Attributes] Item [expr 6]]
                set relatedSA [[$a00 Value] Type]
                set a01 [[[$a0 Value] Attributes] Item [expr 5]]
              }
            } emsg]} {
              set msg "Syntax Error: Bad 'related_shape_aspect' attribute on '[$e0 Type]'."
              errorMsg $msg
              lappend syntaxErr([$e0 Type]) [list [$e0 P21ID] "related_shape_aspect" $msg]
            }


# related SA is OK
            if {[info exists relatedSA]} {relatedShapeAspect $relatedSA $a00 $tolType $dimSize}
          }
        }
      }
    }

# check component_path_shape_aspect direct reference to shape_aspect
    if {$entDefType == "component_path_shape_aspect"} {
      set a0 [[$entDef Attributes] Item [expr 6]]
      set relatedSA [[$a0 Value] Type]
      relatedShapeAspect $relatedSA $a0 $tolType $dimSize
    }
  } emsg]} {
    errorMsg "Error adding Associated Geometry: $emsg"
  }
}

# -------------------------------------------------------------------------------
proc relatedShapeAspect {relatedSA a0 tolType dimSize} {
  set type [appendAssocGeom [$a0 Value] E]
  if {$type == "advanced_face"} {getFaceGeom [$a0 Value] $tolType E}
  if {$dimSize} {checkShapeAspect [$a0 Value]}

  set a0val {}
  if {[string first "composite_shape_aspect" $relatedSA] != -1 || [string first "composite_group_shape_aspect" $relatedSA] != -1 || \
      [string first "centre_of_symmetry" $relatedSA] != -1} {
    set e1s [[$a0 Value] GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
    ::tcom::foreach e1 $e1s {
      if {[string first "relationship" [$e1 Type]] != -1} {
        ::tcom::foreach a1 [$e1 Attributes] {

# get shape_aspect
          if {[$a1 Name] == "related_shape_aspect"} {
            if {[[$a1 Value] Type] == "component_path_shape_aspect"} {set a1 [[[$a1 Value] Attributes] Item [expr 6]]}
            lappend a0val [$a1 Value]
            set type [appendAssocGeom [$a1 Value] F]
            if {$dimSize} {checkShapeAspect [$a1 Value]}
          }
        }
      }
    }
    if {[string first "centre_of_symmetry" $relatedSA] != -1} {lappend a0val [$a0 Value]}
  } else {
    lappend a0val [$a0 Value]
  }

# find AF for SA with GISU or IIRU, check all around
  foreach val $a0val {getAssocGeomFace $val $tolType}
}

# -------------------------------------------------------------------------------
proc getAssocGeomFace {entDef tolType} {
  global entCount opt syntaxErr
  if {$opt(debugAG)} {outputMsg "getAssocGeomFace [$entDef Type] [$entDef P21ID]" green}

# look at GISU and IIRU for geometry associated with shape_aspect
  set usages {}
  foreach str {geometric_item_specific_usage item_identified_representation_usage} {
    if {[info exists entCount($str)]} {if {$entCount($str) > 0} {lappend usages $str}}
  }

  foreach usage $usages {
    set e1s [$entDef GetUsedIn [string trim $usage] [string trim definition]]
    ::tcom::foreach e1 $e1s {

# prevent double counting GISU and IIRU
      set ok 1
      if {[$e1 Type] == "geometric_item_specific_usage" && $usage == "item_identified_representation_usage"} {set ok 0}

      if {$ok} {
        ::tcom::foreach a1 [$e1 Attributes] {
          if {[$a1 Name] == "identified_item"} {
            if {[$a1 Value] != ""} {
              if {[catch {
                set type [appendAssocGeom [$a1 Value] B]
                if {$type == "advanced_face"} {getFaceGeom [$a1 Value] $tolType B}
              } emsg1]} {
                ::tcom::foreach e2 [$a1 Value] {
                  set type [appendAssocGeom $e2 C]
                  if {$type == "advanced_face"} {getFaceGeom $e2 $tolType C}
                }
              }
            } else {
              set msg "Syntax Error: Missing 'identified_item' attribute on '$usage'."
              errorMsg $msg
              lappend syntaxErr($usage) [list [$e1 P21ID] "identified_item" $msg]
            }
          }
        }
      }
    }
  }
}

# -------------------------------------------------------------------------------
proc appendAssocGeom {ent {id ""}} {
  global assocGeom opt

  set p21id [$ent P21ID]
  set type  [$ent Type]
  if {$opt(debugAG)} {outputMsg " appendAssocGeom $type $p21id $id" red}

  if {[string first "annotation" $type] == -1 && [string first "callout" $type] == -1} {
    if {![info exists assocGeom($type)]} {
      lappend assocGeom($type) $p21id
    } elseif {[lsearch $assocGeom($type) $p21id] == -1} {
      lappend assocGeom($type) $p21id
    }
  }
  return $type
}

# -------------------------------------------------------------------------------
proc getFaceGeom {e0 tolType {id ""}} {
  global assocGeom cylSurfBounds dimName opt

  if {$tolType} {set debug 0}

  if {[catch {
    ::tcom::foreach a1 [$e0 Attributes] {
      if {[$a1 Name] == "face_geometry"} {
        set p21id [[$a1 Value] P21ID]
        set type  [[$a1 Value] Type]
        lappend assocGeom($type) $p21id
        set currEnt ""
        if {$opt(debugAG)} {
          outputMsg "  getFaceGeom $type $p21id $id / [$e0 Type] [$e0 P21ID]" red
          if {$tolType && [info exists dimName]} {outputMsg "   dimName $dimName" red}
        }

# for cylindrical, conical, or spherical surfaces with dimensional tolerances (tolType = 1)
#  set cylSurfBounds to 180 or 360 depending on bounds of the surfaces
        set ok 0
        if {$tolType != 1} {set ok 1}
        if {[info exists dimName]} {if {[string first "diameter" $dimName] != -1} {set ok 1}}
        if {$tolType && $ok && ($type == "cylindrical_surface" || $type == "conical_surface" || $type == "spherical_surface")} {

# face bounds
          set a2 [[$e0 Attributes] Item [expr 2]]
          ::tcom::foreach e3 [$a2 Value] {
            set currEnt [$e3 Type]
            if {$debug} {outputMsg "e3  [$e3 Type] [$e3 P21ID]"}
            set a4 [[$e3 Attributes] Item [expr 2]]
# edge loops
            set e4 [$a4 Value]
            set currEnt [$e4 Type]
            if {$debug} {outputMsg "e4   [$e4 Type] [$e4 P21ID]"}

            if {[$e4 Type] == "edge_loop"} {
              set a5s [[$e4 Attributes] Item [expr 2]]
# oriented edge
              ::tcom::foreach e5 [$a5s Value] {
                set currEnt [$e5 Type]
                if {$debug} {outputMsg "e5    [$e5 Type] [$e5 P21ID]"}
                set a6 [[$e5 Attributes] Item [expr 4]]
# edge curve
                set e6 [$a6 Value]
                set currEnt [$e6 Type]
                if {$debug} {outputMsg "e6     [$e6 Type] [$e6 P21ID]"}
                set a7 [[$e6 Attributes] Item [expr 4]]
                set e7 [$a7 Value]
                set currEnt [$e7 Type]
                if {$debug} {outputMsg "e7      [$e7 Type] [$e7 P21ID]"}
                if {[$e7 Type] == "circle"} {
                  foreach i [list 2 3] {
# vertex point
                    set a7 [[$e6 Attributes] Item [expr $i]]
                    set e7 [$a7 Value]
                    set currEnt [$e7 Type]
                    if {$debug} {outputMsg "       $i [$e7 Type] [$e7 P21ID]"}
# cartesian point
                    set a8 [[$e7 Attributes] Item [expr 2]]
                    set e8 [$a8 Value]
                    set currEnt [$e8 Type]
                    if {$debug} {outputMsg "        $i [$e8 Type] [$e8 P21ID]"}
                    set id1($i) [$e8 P21ID]
                  }

# cartesian point IDs are the same
                  if {$id1(2) == $id1(3)} {
                    set cylSurfBounds 360
                  } else {
                    set cylSurfBounds 180
                  }
                }
              }
            } else {
              errorMsg "Edges defined by '[$e4 Type]' for an Associated Geometry face are not supported."
            }
          }
        } else {
          catch {unset cylSurfBounds}
        }
      }
    }
  } emsg]} {
    errorMsg "Error getting Face Geometry ($currEnt): $emsg"
  }
}

# -------------------------------------------------------------------------------
proc reportAssocGeom {entType {row ""}} {
  global objDesign
  global assocGeom cells cgrObjects cylSurfBounds dimName dimRepeat dimRepeatDiv entCount multipleDatumFeature opt recPracNames spaces suppGeomEnts syntaxErr
  if {$opt(debugAG)} {outputMsg "reportAssocGeom $entType" green}

  set str ""
  set dimRepeat 0
  set dimtol 0
  if {[string first "dimensional_" $entType] != -1 || [string first "angular_" $entType] != -1} {
    set dimtol 1

# set divider based on cylinders, assume two half cylinders, but different if dim is a radius because cylinders are not closed
    set dimRepeatDiv 2
    if {[info exists dimName]} {if {$dimName == "radius"} {set dimRepeatDiv 1}}
  }

# geometric entities
  foreach item [array names assocGeom] {
    if {[string first "shape_aspect" $item] == -1 && [string first "centre" $item] == -1 && \
        [string first "datum" $item] == -1 && [string first "_callout" $item] == -1 && $item != "advanced_face"} {
      if {[string length $str] > 0} {append str [format "%c" 10]}
      set nstr "([llength $assocGeom($item)]) [formatComplexEnt $item] [lsort -integer $assocGeom($item)]"
      if {[string first $nstr $str] == -1} {append str $nstr}

# repetitive hole dimension count, e.g. 4X
      set dc [llength $assocGeom($item)]
      if {[string first "_size" $entType] != -1 || [string first "angular_location" $entType] != -1} {
        if {$item == "cylindrical_surface" || $item == "conical_surface" || $item == "spherical_surface" || $item == "toroidal_surface"} {
          if {![info exists cylSurfBounds]} {

# set divider if odd number of cylinders, then one complete cylinder
            if {$dc == 1} {set dimRepeatDiv 1}

            if {$dimRepeatDiv == 1} {
              if {$dc > 1} {incr dimRepeat $dc}
            } else {
              if {[expr {$dc%2}] == 0} {
                if {$dc > 3} {incr dimRepeat [expr {$dc/2}]}
              } else {
                if {$dc > 1} {incr dimRepeat $dc}
              }
            }

# set number of cylinders based on value from getFaceGeom
          } elseif {$cylSurfBounds == 360} {
            incr dimRepeat $dc
          } elseif {$cylSurfBounds == 180} {
            incr dimRepeat [expr {$dc/2}]
          }
        }
      }
    }
  }

# advanced face
  foreach item [array names assocGeom] {
    if {$item == "advanced_face"} {
      if {[string length $str] > 0} {append str [format "%c" 10]}
      append str "([llength $assocGeom(advanced_face)]) $item [lsort -integer $assocGeom(advanced_face)]"
    }
  }

# missing geometry
  if {$dimtol || [string first "occurrence" $entType] != -1} {
    set str1 "Sec. 5.1, Figs. 5, 6, 12"
    set str2 "Associated"
  } else {
    set str1 "Sec. 6.5, Fig. 35"
    set str2 "Toleranced"
    if {[string first "datum_feature" $entType] != -1} {set str2 "Associated"}
  }
  if {[string length $str] == 0} {
    if {$dimtol || [string first "occurrence" $entType] != -1} {
      set str1 "Sec. 5.1, Figs. 5, 6, 12"
      set str2 "Associated"
    } else {
      set str1 "Sec. 6.5, Fig. 35"
      set str2 "Toleranced"
      if {[string first "datum_feature" $entType] != -1} {set str2 "Associated"}
    }

# get column with the name heading and check
    set ok 1
    if {[string first "occurrence" $entType] != -1} {
      if {!$opt(INVERSE)} {
        set c E
        if {[string first "placeholder" $entType] != -1} {
          set c G
          if {[string first "leader_line" $entType] != -1} {set c H}
       }
      } else {
        foreach c1 {I H G F E} {
          set head [[$cells($entType) Item 3 $c1] Value]
          if {[string first "name" $head] == 0} {set c $c1; break}
        }
      }
      set val [[$cells($entType) Item $row $c] Value]
      foreach str3 {note title block label text} {if {[string first $str3 $val] != -1} {set ok 0}}
    }
    if {$ok} {
      set etyp "entity"
      if {[string first "annotation" $entType] != -1} {set etyp "annotation"}
      if {[string first "tolerance"  $entType] != -1} {set etyp "tolerance"}
      if {[string first "dimension"  $entType] != -1} {set etyp "dimension"}
      if {[string first "datum_feature" $entType] != -1} {set etyp "datum feature"}

# message only if there are advanced_face
      if {[info exists entCount(advanced_face)]} {
        if {$entCount(advanced_face) > 0} {
          set msg "$str2 Geometry not found for a [formatComplexEnt $entType].  If the $etyp should have $str2 Geometry, then check GISU or IIRU 'definition' attribute or shape_aspect_relationship 'relating_shape_aspect' attribute.  Select Inverse Relationships on the Generate tab to check relationships for shape_aspect.\n  ($recPracNames(pmi242), $str1)"
          errorMsg $msg
          if {$row != ""} {
            set idx $entType
            if {$dimtol} {set idx "dimensional_characteristic_representation"}
            lappend syntaxErr($idx) [list "-$row" "$str2 Geometry" $msg]
          }
        }
      }
    }
  }

# shape aspect
  set multipleDatumFeature 0
  foreach item [array names assocGeom] {
    if {[string first "shape_aspect" $item] != -1 || [string first "centre" $item] != -1 || [string first "datum_feature" $item] != -1 || [string first "datum_target" $item] != -1} {
      if {[string length $str] > 0} {append str [format "%c" 10]}
      append str "([llength $assocGeom($item)]) [formatComplexEnt $item] [lsort -integer $assocGeom($item)]"
      if {[string first "tolerance" $entType] != -1 && [string first "datum_feature" $item] != -1 && [llength $assocGeom($item)] > 1} {
        set msg "Associated Geometry has multiple ([llength $assocGeom($item)]) [formatComplexEnt $item] for a [formatComplexEnt $entType]."
        errorMsg $msg
        set multipleDatumFeature 1
      }
    }
  }

# check CGSA, all around, and between with less than 2 SA
  set ncsa 0
  set nsa 0
  foreach item [array names assocGeom] {
    if {[string first "composite_group_shape_aspect" $item] != -1 || [string first "composite_shape_aspect" $item] != -1 || \
        $item == "all_around_shape_aspect" || $item == " between_shape_aspect"} {
      set ncsa [llength $assocGeom($item)]
      set csaEnt $item
    } elseif {$item == "shape_aspect" || $item == "centre_of_symmetry" || $item == "datum_feature" || $item == "geometric_alignment" || [string first "datum_target" $item] != -1} {
      incr nsa [llength $assocGeom($item)]
    }
    if {($ncsa == 1 && $nsa < 2) || ($ncsa > 1 && $ncsa == $nsa)} {
      set msg "Syntax Error: '[formatComplexEnt $csaEnt]' must relate to at least two 'shape_aspect' or similar entities.  Check shape_aspect_relationship 'relating_shape_aspect' attribute.$spaces\($recPracNames(pmi242), Sec. 6.3, 6.4, 6.5)"
      errorMsg $msg
      if {$row != ""} {
        set typ $entType
        if {$dimtol} {set typ "dimensional_characteristic_representation"}
        lappend syntaxErr($typ) [list "-$row" $str2 $msg]
      }
    }
  }

# get entity IDs for supplemental geometry once
  if {![info exists suppGeomEnts]} {
    set suppGeomEnts {}
    if {[info exists entCount(constructive_geometry_representation)]} {
      if {$entCount(constructive_geometry_representation) > 0} {

# find items in CGR
        set cgrItems {}
        set cgrObjects [$objDesign FindObjects [string trim constructive_geometry_representation]]
        ::tcom::foreach e0 $cgrObjects {
          set a1 [[$e0 Attributes] Item [expr 2]]
          ::tcom::foreach e2 [$a1 Value] {
            lappend cgrItems [$e2 P21ID]

# find trimmed_curve for composite_curve and add to cgrItems
            if {[$e2 Type] == "composite_curve"} {
              ::tcom::foreach ccs [[[$e2 Attributes] Item [expr 2]] Value] {
                lappend cgrItems [[[[$ccs Attributes] Item [expr 3]] Value] P21ID]
              }

# find items in geometric_curve_set
            } elseif {[$e2 Type] == "geometric_curve_set"} {
              foreach e3 [[[$e2 Attributes] Item [expr 2]] Value] {lappend cgrItems [$e3 P21ID]}
            }
          }
        }

# find identified_items in GISU for CGR
        set okcgr 1
        ::tcom::foreach gisu [$objDesign FindObjects [string trim geometric_item_specific_usage]] {
          set attrerr ""
          set attr [$gisu Attributes]
          set ur [$attr Item [expr 4]]
          if {[$ur Value] != ""} {
            if {[[$ur Value] Type] == "constructive_geometry_representation"} {
              set ii [$attr Item [expr 5]]
              if {[$ii Value] != ""} {
                set p21id [[$ii Value] P21ID]
                if {[lsearch $suppGeomEnts $p21id] == -1} {lappend suppGeomEnts $p21id}
                if {[lsearch $cgrItems $p21id] == -1} {
                  set okcgr 0
                  set msg "Syntax Error: 'constructive_geometry_representation' is missing some 'items' based on GISU 'identified_item' attribute.$spaces\($recPracNames(suppgeom), Sec. 4.3, Fig. 4)"
                  errorMsg $msg
                  lappend syntaxErr(geometric_item_specific_usage) [list [$gisu P21ID] identified_item $msg]
                }
              } else {
                set attrerr "identified_item"
                set msg "Syntax Error: Missing 'identified_item' attribute on 'geometric_item_specific_usage'."
                errorMsg $msg
                lappend syntaxErr(geometric_item_specific_usage) [list [$gisu P21ID] identified_item $msg]
              }
            }
          }
        }

        if {!$okcgr} {
          set msg "Syntax Error: 'constructive_geometry_representation' is missing some 'items' based on GISU 'identified_item' attribute.$spaces\($recPracNames(suppgeom), Sec. 4.3, Fig. 4)"
          errorMsg $msg
          lappend syntaxErr(constructive_geometry_representation) [list [$e0 P21ID] items $msg]
        }
      }
    }
  }

# check for supplemental geometry in associated geometry
  foreach id $suppGeomEnts {
    set c1 [string first $id $str]
    if {$c1 != -1} {
      set lid [string length $id]
      set nid "$id*"
      set str [string replace $str $c1 [expr {$c1+$lid-1}] $nid]
    }
  }
  return $str
}

# -------------------------------------------------------------------------------
proc checkShapeAspect {ent} {
  global syntaxErr recPracNames spaces

  if {[string first "datum" [$ent Type]] == -1} {
    if {[[[$ent Attributes] Item [expr 4]] Value] == 0} {
      set msg "Syntax Error: For dimensional_size, the related [$ent Type] 'product_definitional' attribute should be TRUE.$spaces\($recPracNames(pmi242), Sec. 3.4)"
      errorMsg $msg
      lappend syntaxErr([$ent Type]) [list [$ent P21ID] "product_definitional" $msg]
    }
  }
}
