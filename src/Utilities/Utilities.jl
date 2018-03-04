"""
Provides a collection of utility functions and types that are used in other submodules.
"""
module Utilities

using Base.Meta, Compat
import Base: isdeprecated, Docs.Binding
using DocStringExtensions
import Compat.Markdown

# Logging output.

const __log__ = Ref(true)
"""
    logging(flag::Bool)

Enable or disable logging output for [`log`](@ref) and [`warn`](@ref).
"""
logging(flag::Bool) = __log__[] = flag

"""
Format and print a message to the user.
"""
log(msg) = __log__[] ? printstyled(stdout, "Documenter: ", msg, "\n", color=:magenta) : nothing

# Print logging output to the "real" stdout.struct ThematicBreak <: MarkdownBlockNode end
function log(doc, msg)
    __log__[] && printstyled(stdout, "Documenter: ", msg, "\n", color=:magenta)
    return nothing
end

debug(msg) = printstyled(" ?? ", msg, "\n", color=:green)

"""
    warn(file, msg)
    warn(msg)

Format and print a warning message to the user. Passing a `file` will include the filename
where the warning was raised.
"""
function warn(file, msg)
    if __log__[]
        msg = string(" !! ", msg, " [", file, "]\n")
        printstyled(stdout, msg, color=:red)
    else
        nothing
    end
end
warn(msg) = __log__[] ? printstyled(stdout, " !! ", msg, "\n", color=:red) : nothing

function warn(file, msg, err, ex, mod)
    if __log__[]
        warn(file, msg)
        printstyled(stdout, "\nERROR: $err\n\nexpression '$ex' in module '$mod'\n\n", color=:red)
    else
        nothing
    end
end

function warn(doc, page, msg, err)
    file = page.source
    printstyled(stdout, " !! Warning in $(file):\n\n$(msg)\n\nERROR: $(err)\n\n", color=:red)
end

# Directory paths.

"""
Returns the current directory.
"""
function currentdir()
    d = Base.source_dir()
    d === nothing ? pwd() : d
end

"""
Returns the path to the Documenter `assets` directory.
"""
assetsdir() = normpath(joinpath(dirname(@__FILE__), "..", "..", "assets"))

cleandir(d::AbstractString) = (isdir(d) && rm(d, recursive = true); mkdir(d))

"""
Find the path of a file relative to the `source` directory. `root` is the path
to the directory containing the file `file`.

It is meant to be used with `walkdir(source)`.
"""
srcpath(source, root, file) = normpath(joinpath(relpath(root, source), file))

# Slugify text.

"""
Slugify a string into a suitable URL.
"""
function slugify(s::AbstractString)
    s = replace(s, r"\s+" => "-")
    s = replace(s, r"^\d+" => "")
    s = replace(s, r"&" => "-and-")
    s = replace(s, r"[^\p{L}\p{P}\d\-]+" => "")
    s = strip(replace(s, r"\-\-+" => "-"), '-')
end
slugify(object) = string(object) # Non-string slugifying doesn't do anything.

# Parse code blocks.

"""
Returns a vector of parsed expressions and their corresponding raw strings.

Returns a `Vector` of tuples `(expr, code)`, where `expr` is the corresponding expression
(e.g. a `Expr` or `Symbol` object) and `code` is the string of code the expression was
parsed from.

The keyword argument `skip = N` drops the leading `N` lines from the input string.
"""
function parseblock(code::AbstractString, doc, page; skip = 0, keywords = true)
    # Drop `skip` leading lines from the code block. Needed for deprecated `{docs}` syntax.
    code = string(code, '\n')
    code = last(split(code, '\n', limit = skip + 1))
    # Check whether we have windows-style line endings.
    offset = contains(code, "\n\r") ? 2 : 1
    endofstr = lastindex(code)
    results = []
    cursor = 1
    while cursor < endofstr
        # Check for keywords first since they will throw parse errors if we `parse` them.
        line = match(r"^(.+)$"m, SubString(code, cursor)).captures[1]
        keyword = Symbol(strip(line))
        (ex, ncursor) =
            if keywords && haskey(Docs.keywords, keyword)
                # adding offset below should be OK, as `\n` and `\r` are single byte
                (QuoteNode(keyword), cursor + lastindex(line) + offset)
            else
                try
                    Meta.parse(code, cursor)
                catch err
                    push!(doc.internal.errors, :parse_error)
                    Utilities.warn(doc, page, "Failed to parse expression.", err)
                    break
                end
            end
        push!(results, (ex, SubString(code, cursor, prevind(code, ncursor))))
        cursor = ncursor
    end
    results
end
isassign(x) = isexpr(x, :(=), 2) && isa(x.args[1], Symbol)

# Checking arguments.

"""
Prints a formatted warning to the user listing unrecognised keyword arguments.
"""
function check_kwargs(kws)
    isempty(kws) && return
    out = IOBuffer()
    println(out, "Unknown keywords:\n")
    for (k, v) in kws
        println(out, "  ", k, " = ", v)
    end
    warn(String(take!(out)))
end

# Finding submodules.

const ModVec = Union{Module, Vector{Module}}

"""
Returns the set of submodules of a given root module/s.
"""
function submodules(modules::Vector{Module})
    out = Set{Module}()
    for each in modules
        submodules(each, out)
    end
    out
end
function submodules(root::Module, seen = Set{Module}())
    push!(seen, root)
    for name in Compat.names(root, all=true)
        if Base.isidentifier(name) && isdefined(root, name) && !isdeprecated(root, name)
            object = getfield(root, name)
            if isa(object, Module) && !(object in seen)
                submodules(object, seen)
            end
        end
    end
    return seen
end



## objects
## =======



"""
Represents an object stored in the docsystem by its binding and signature.
"""
struct Object
    binding   :: Binding
    signature :: Type

    function Object(b::Binding, signature::Type)
        m = nameof(b.mod) === b.var ? parentmodule(b.mod) : b.mod
        new(Binding(m, b.var), signature)
    end
end

function splitexpr(x::Expr)
    isexpr(x, :macrocall) ? splitexpr(x.args[1]) :
    isexpr(x, :.)         ? (x.args[1], x.args[2]) :
    error("Invalid @var syntax `$x`.")
end
splitexpr(s::Symbol) = :(Main), quot(s)
splitexpr(other)     = error("Invalid @var syntax `$other`.")

"""
    object(ex, str)

Returns a expression that, when evaluated, returns an [`Object`](@ref) representing `ex`.
"""
function object(ex::Union{Symbol, Expr}, str::AbstractString)
    binding   = Expr(:call, Binding, splitexpr(Docs.namify(ex))...)
    signature = Base.Docs.signature(ex)
    isexpr(ex, :macrocall, 1 + Compat.macros_have_sourceloc) && !endswith(str, "()") && (signature = :(Union{}))
    Expr(:call, Object, binding, signature)
end

function object(qn::QuoteNode, str::AbstractString)
    if haskey(Base.Docs.keywords, qn.value)
        binding = Expr(:call, Binding, Main, qn)
        Expr(:call, Object, binding, Union{})
    else
        error("'$(qn.value)' is not a documented keyword.")
    end
end

function Base.print(io::IO, obj::Object)
    print(io, obj.binding)
    print_signature(io, obj.signature)
end
print_signature(io::IO, signature::Union{Union, Type{Union{}}}) = nothing
print_signature(io::IO, signature)        = print(io, '-', signature)

## docs
## ====

"""
    docs(ex, str)

Returns an expression that, when evaluated, returns the docstrings associated with `ex`.
"""
function docs end

# Macro representation changed between 0.4 and 0.5.
function docs(ex::Union{Symbol, Expr}, str::AbstractString)
    isexpr(ex, :macrocall, 1 + Compat.macros_have_sourceloc) && !endswith(rstrip(str), "()") && (ex = quot(ex))
    :(Base.Docs.@doc $ex)
end
docs(qn::QuoteNode, str::AbstractString) = :(Base.Docs.@doc $(qn.value))

"""
Returns the category name of the provided [`Object`](@ref).
"""
doccat(obj::Object) = startswith(string(obj.binding.var), '@') ?
    "Macro" : doccat(obj.binding, obj.signature)

function doccat(b::Binding, ::Union{Union, Type{Union{}}})
    if b.mod === Main && haskey(Base.Docs.keywords, b.var)
        "Keyword"
    elseif startswith(string(b.var), '@')
        "Macro"
    else
        doccat(getfield(b.mod, b.var))
    end
end

doccat(b::Binding, ::Type)  = "Method"

doccat(::Function) = "Function"
doccat(::DataType) = "Type"
doccat(x::UnionAll) = doccat(Base.unwrap_unionall(x))
doccat(::Module)   = "Module"
doccat(::Any)      = "Constant"

"""
    filterdocs(doc, modules)

Remove docstrings from the markdown object, `doc`, that are not from one of `modules`.
"""
function filterdocs(doc::Markdown.MD, modules::Set{Module})
    if isempty(modules)
        # When no modules are specified in `makedocs` then don't filter anything.
        doc
    else
        if haskey(doc.meta, :module)
            doc.meta[:module] ∈ modules ? doc : nothing
        else
            if haskey(doc.meta, :results)
                out = []
                results = []
                for (each, result) in zip(doc.content, doc.meta[:results])
                    r = filterdocs(each, modules)
                    if r !== nothing
                        push!(out, r)
                        push!(results, result)
                    end
                end
                if isempty(out)
                    nothing
                else
                    md = Markdown.MD(out)
                    md.meta[:results] = results
                    md
                end
            else
                out = []
                for each in doc.content
                    r = filterdocs(each, modules)
                    r === nothing || push!(out, r)
                end
                isempty(out) ? nothing : Markdown.MD(out)
            end
        end
    end
end
# Non-markdown docs won't have a `.meta` field so always just accept those.
filterdocs(other, modules::Set{Module}) = other

"""
Does the given docstring represent actual documentation or a no docs error message?
"""
nodocs(x)      = contains(stringmime("text/plain", x), "No documentation found.")
nodocs(::Nothing) = false

header_level(::Markdown.Header{N}) where {N} = N

# Finding URLs -- based partially on code from the main Julia repo in `base/methodshow.jl`.
#
# Paths on Windows contain backslashes, so the `url` function needs to take care of them.
# However, the exact formatting is not consistent and depends on whether Julia runs
# separately or in Cygwin.
#
# We get paths from Julia's docsystem, e.g.
#     Docs.docstr(Docs.Binding(Documenter,:Documenter)).data[:path]
# and from git
#     git rev-parse --show-toplevel
#
# * Ordinary Windows binaries (both Julia and git)
#   In this case the paths from the docsystem are Windows-like with backslashes, e.g.:
#       C:\Users\<user>\.julia\v0.6\Documenter\src\Documenter.jl
#   But the paths from git have forward slashes, e.g.:
#       C:/Users/<user>julia/v0.6/Documenter
#
# * Running under Cygwin
#   The paths from the docsystem are the same as before, e.g.:
#       C:\Users\<user>\.julia\v0.6\Documenter\src\Documenter.jl
#   However, git returns UNIX-y paths using a /cygdrive mount, e.g.:
#       /cygdrive/c/<user>/.julia/v0.6/Documenter
#   We can fix that with `cygpath -m <path>` to get a Windows-like path with forward
#   slashes, e.g.:
#       C:/Users/<user>/.julia/v0.6/Documenter)
#
# In the docsystem paths we replace the backslashes with forward slashes before we start
# comparing paths with the ones from git.
#

"""
    in_cygwin()

Check if we're running under cygwin. Useful when we need to translate cygwin paths to
windows paths.
"""
function in_cygwin()
    if Compat.Sys.iswindows()
        try
            return success(`cygpath -h`)
        catch
            return false
        end
    else
        return false
    end
end

function relpath_from_repo_root(file)
    cd(dirname(file)) do
        root = readchomp(`git rev-parse --show-toplevel`)
        if in_cygwin()
            root = readchomp(`cygpath -m "$root"`)
        end
        startswith(file, root) ? relpath(file, root) : nothing
    end
end

function repo_commit(file)
    cd(dirname(file)) do
        readchomp(`git rev-parse HEAD`)
    end
end

function url(repo, file; commit=nothing)
    file = realpath(abspath(file))
    remote = getremote(dirname(file))
    isempty(repo) && (repo = "https://github.com/$remote/blob/{commit}{path}")
    # Replace any backslashes in links, if building the docs on Windows
    file = replace(file, '\\' => '/')
    path = relpath_from_repo_root(file)
    if path === nothing
        nothing
    else
        repo = replace(repo, "{commit}" => commit === nothing ? repo_commit(file) : commit)
        repo = replace(repo, "{path}" => string("/", path))
        repo
    end
end

url(remote, repo, doc) = url(remote, repo, doc.data[:module], doc.data[:path], linerange(doc))

function url(remote, repo, mod, file, linerange)
    remote = getremote(dirname(file))
    isabspath(file) && isempty(remote) && isempty(repo) && return nothing

    # make sure we get the true path, as otherwise we will get different paths when we compute `root` below
    if isfile(file)
        file = realpath(abspath(file))
    end

    # Replace any backslashes in links, if building the docs on Windows
    file = replace(file, '\\' => '/')
    # Format the line range.
    line = format_line(linerange, LineRangeFormatting(repo_host_from_url(repo)))
    # Macro-generated methods such as those produced by `@deprecate` list their file as
    # `deprecated.jl` since that is where the macro is defined. Use that to help
    # determine the correct URL.
    if inbase(mod) || !isabspath(file)
        base = "https://github.com/JuliaLang/julia/blob"
        dest = "base/$file#$line"
        if isempty(Base.GIT_VERSION_INFO.commit)
            "$base/v$VERSION/$dest"
        else
            commit = Base.GIT_VERSION_INFO.commit
            "$base/$commit/$dest"
        end
    else
        path = relpath_from_repo_root(file)
        if isempty(repo)
            repo = "https://github.com/$remote/blob/{commit}{path}#{line}"
        end
        if path === nothing
            nothing
        else
            repo = replace(repo, "{commit}" => repo_commit(file))
            repo = replace(repo, "{path}" => string("/", path))
            repo = replace(repo, "{line}" => line)
            repo
        end
    end
end

function getremote(dir::AbstractString)
    remote =
        try
            cd(() -> readchomp(`git config --get remote.origin.url`), dir)
        catch err
            ""
        end
    m = match(Compat.LibGit2.GITHUB_REGEX, remote)
    if m === nothing
        travis = get(ENV, "TRAVIS_REPO_SLUG", "")
        isempty(travis) ? "" : travis
    else
        m[1]
    end
end

"""
$(SIGNATURES)

Returns the first 5 characters of the current git commit hash of the directory `dir`.
"""
function get_commit_short(dir)
    commit = cd(dir) do
        readchomp(`git rev-parse HEAD`)
    end
    (length(commit) > 5) ? commit[1:5] : commit
end

function inbase(m::Module)
    if m ≡ Base
        true
    else
        parent = parentmodule(m)
        parent ≡ m ? false : inbase(parent)
    end
end

# Repository hosts
#   RepoUnknown denotes that the repository type could not be determined automatically
@enum RepoHost RepoGithub RepoBitbucket RepoGitlab RepoUnknown

# Repository host from repository url
# i.e. "https://github.com/something" => RepoGithub
#      "https://bitbucket.org/xxx" => RepoBitbucket
# If no match, returns RepoUnknown
function repo_host_from_url(repoURL::String)
    if contains(repoURL, "bitbucket")
        return RepoBitbucket
    elseif contains(repoURL, "github")
        return RepoGithub
    elseif contains(repoURL, "gitlab")
        return RepoGitlab
    else
        return RepoUnknown
    end
end

# Find line numbers.
# ------------------

linerange(doc) = linerange(doc.text, doc.data[:linenumber])

function linerange(text, from)
    lines = sum([isodd(n) ? newlines(s) : 0 for (n, s) in enumerate(text)])
    return lines > 0 ? (from:(from + lines + 1)) : (from:from)
end

struct LineRangeFormatting
    prefix::String
    separator::String

    function LineRangeFormatting(host::RepoHost)
        if host == RepoBitbucket
            new("", ":")
        else
            # default is github-style
            new("L", "-")
        end
    end
end

function format_line(range::Compat.AbstractRange, format::LineRangeFormatting)
    local top = format_line(first(range), format.prefix)
    return length(range) <= 1 ? top : string(top, format.separator, format_line(last(range), format.prefix))
end
format_line(line::Integer, prefix::String) = string(prefix, line)

newlines(s::AbstractString) = count(c -> c === '\n', s)
newlines(other) = 0


# Output redirection.
# -------------------

"""
Call a function and capture all `stdout` and `stderr` output.

    withoutput(f) --> (result, success, backtrace, output)

where

  * `result` is the value returned from calling function `f`.
  * `success` signals whether `f` has thrown an error, in which case `result` stores the
    `Exception` that was raised.
  * `backtrace` a `Vector{Ptr{Cvoid}}` produced by `catch_backtrace()` if an error is thrown.
  * `output` is the combined output of `stdout` and `stderr` during execution of `f`.

"""
function withoutput(f)
    # Save the default output streams.
    default_stdout = stdout
    default_stderr = stderr

    # Redirect both the `stdout` and `stderr` streams to a single `Pipe` object.
    pipe = Pipe()
    Base.link_pipe(pipe; julia_only_read = true, julia_only_write = true)
    redirect_stdout(pipe.in)
    redirect_stderr(pipe.in)

    # Bytes written to the `pipe` are captured in `output` and converted to a `String`.
    output = UInt8[]

    # Run the function `f`, capturing all output that it might have generated.
    # Success signals whether the function `f` did or did not throw an exception.
    result, success, backtrace =
        try
            f(), true, Vector{Ptr{Cvoid}}()
        catch err
            err, false, catch_backtrace()
        finally
            # Force at least a single write to `pipe`, otherwise `readavailable` blocks.
            println()
            # Restore the original output streams.
            redirect_stdout(default_stdout)
            redirect_stderr(default_stderr)
            # NOTE: `close` must always be called *after* `readavailable`.
            append!(output, readavailable(pipe))
            close(pipe)
        end
    return result, success, backtrace, chomp(String(output))
end


"""
    issubmodule(sub, mod)

Checks whether `sub` is a submodule of `mod`. A module is also considered to be
its own submodule.

E.g. `A.B.C` is a submodule of `A`, `A.B` and `A.B.C`, but it is not a submodule
of `D`, `A.D` nor `A.B.C.D`.
"""
function issubmodule(sub, mod)
    if (sub === Main) && (mod !== Main)
        return false
    end
    (sub === mod) || issubmodule(parentmodule(sub), mod)
end

"""
    isabsurl(url)

Checks whether `url` is an absolute URL (as opposed to a relative one).
"""
isabsurl(url) = contains(url, ABSURL_REGEX)
const ABSURL_REGEX = r"^[[:alpha:]+-.]+://"

include("DOM.jl")
include("MDFlatten.jl")
include("TextDiff.jl")
include("Selectors.jl")
include("Markdown2.jl")

end
