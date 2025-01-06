export-env {
  let build_root = ($nu.home-path | path join ".mtb_build")
  $env.REPOS_ROOT = ($nu.home-path | path join "dev")
  let os = $nu.os-info
  $env.opts = {
    name: ($env.GITHUB_REPOSITORY | path basename)
    windows: ($os.name == windows)
    linux: ($os.name == linux)
    darwin: ($os.name == macos)
    prefix: $"($os.name)_($os.arch)"
    workspace: $env.GITHUB_WORKSPACE
  }

  $env.MTB_BUILD_ROOT = $build_root
  mkdir $build_root
  mkdir $env.REPOS_ROOT
}

# get a build root by name
export def get-build-root [name: string] {
  $env.MTB_BUILD_ROOT | path join $name
}

export def "git grab" [url] {
  cd $env.REPOS_ROOT
  let repo_name = ($url | path basename)

  if ($repo_name | path exists) {
    cd $repo_name
    git fetch
    git pull
    git submodule update --init --recursive
    return $env.PWD
  } else {
    git clone --recurse-submodules $url
    cd $repo_name
    return $env.PWD
  }
}

export def compress [to_compress, archive_name?] {
  let name = $archive_name | default ($to_compress | path parse | get stem)
  let common = [$name $to_compress]
  let exe = if $env.opts.windows {
    "7z"
  } else {
    "zip"
  }
  if $env.opts.windows {
    let args = ["-mfb=258" "-tzip"]
    ^$exe a ...$args ...$common
  } else {
    ^$exe -r -9 -y -m ...$common
  }
}

export def zip-release [folder: path, release_name: string] {
  let folder_name = ($folder | path basename)
  let name = $"($folder_name)-($env.opts.prefix)-($release_name).zip"
  compress $folder_name $name
  return $name
}

# easily send a nu record to the github env or step output
export def to-github [
  --prefix: string
  --output (-o) #  use step output instead of env
] {
  let inrec = $in
  let prefix = ($prefix | default "")

  let res = (
    $inrec | columns | zip ($inrec | values)
    | each {|i|
      $"($prefix)($i.0)=($i.1)"
    }
  )

  if $output {
    $res | to text | save -a $env.GITHUB_OUTPUT
  } else {
    $res | to text | save -a $env.GITHUB_ENV
  }
}

# clone or update a git repo
export def clone-or-update [dest: path, url: string] {
  if not ($dest | path exists) {
    git clone --recursive $url $dest
  }
  cd $dest
  git fetch
  git pull
}

# Display a tree from the given path
export def tree [root?: path = ".", indent = ""] {
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
