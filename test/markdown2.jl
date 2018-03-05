import Documenter.Utilities: Markdown2
import Markdown

###

const INDENT = ".   "

printmd2(xs :: Markdown2.MD) = printmd2(xs.nodes)

function printmd2(xs :: Vector; indent=0)
    for x in xs
        printmd2(x; indent = indent)
    end
end

function printmd2(x::T; indent=0) where T <: Markdown2.MarkdownNode
    if :nodes in fieldnames(T)
        print(INDENT^indent)
        print(typeof(x))

        print(" : ")
        for field in fieldnames(T)
            field == :nodes && continue
            print("$field='$(getfield(x, field))' ")
        end

        println()
        printmd2(x.nodes; indent = indent + 1)
    else
        print(INDENT^indent)
        print(x)
        println()
    end
end

function printmd2(x::Markdown2.List; indent=0)
    print(INDENT^indent)
    print(typeof(x))

    print(" : ")
    for field in fieldnames(Markdown2.List)
        field == :items && continue
        print("$field='$(getfield(x, field))' ")
    end

    println()
    printmd2(x.items; indent = indent + 1)
end

function printmd2(x::Markdown2.Table; indent=0)
    print(INDENT^indent)
    print(typeof(x))

    print(" : ")
    for field in fieldnames(Markdown2.Table)
        field == :cells && continue
        print("$field='$(getfield(x, field))' ")
    end

    println()

    for i = 1:size(x.cells, 1), j = 1:size(x.cells, 1)
        print(INDENT^(indent+1))
        println("cell $i - $j")
        printmd2(x.cells[i,j]; indent = indent + 2)
    end
end

### ---------------------------------

md = Markdown.parse("""
    # Header

    Hello World _hehe foo bar **asd**_!!

    ![Image Title](https://image.com/asdfp.png "alt text")

    Foo Bar \\
    Baz

    - a __em__
    - b
    - c

    end

    ---

    ```language
    Hello
    > World!
    ```

    > Block
    > ``z+1``
    > Quote!
    >
    > ```math
    > x^2 + y^2 = z^2
    > ```

    --- ---

    A[^1] B[^fn]

    [^1]: Hello [World](https://google.com "link title")

    `code span`

    <a@b.com>

    !!! warn "HAHAHA"
        Hellow

        ``math
        x+1
        ``

    ---

    | Column One | Column Two | Column Three |
    |:---------- | ---------- |:------------:|
    | Row `1`    | Column `2` | > asd        |
    | *Row* 2    | **Row** 2  | Column ``3`` |

    """)

md2 = Markdown2.convert(md)

printmd2(md2)
