export-env {
  let build_root = ($nu.home-path | path join ".mtb_build")
  $env.MTB_BUILD_ROOT = $build_root
  mkdir $build_root
}

# get a build root by name
export def get-root [name:string] {
  $env.MTB_BUILD_ROOT | path join $name
}

# easily send a nu record to the github env or step output
export def to-github [
  --output(-o) #  use step output instead of env
] {
  let inrec = $in

  let res = ($inrec | columns | zip ($inrec | values) | each {|i|
    $"($i.0)=($i.1)"} | to text) 

  if $output {
    $res | save -a $env.GITHUB_OUTPUT
  } else {
    $res | save -a $env.GITHUB_ENV
  }
}

# clone or update a git repo
export def clone-or-update [dest:path, url:string] {
    if not ($dest | path exists) {
        git clone  --recursive $url $dest
    }
    cd $dest
    git fetch
    git pull
}

# Display a tree from the given path
export def tree [root?:path=".", indent = ""] {
  let entries = (ls $root)
  for entry in $entries {
    let name = $entry.name
    
    if ($entry.type == "dir") {
      print $"($indent)|-- ($name)"
      tree $entry.name ($indent + "|    ")
    } else {
      print $"($indent)|-- ($name)"
    }
  }
}

