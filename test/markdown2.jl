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
            print("$field='$(getfield(x, field))'")
        end

        println()
        printmd2(x.nodes; indent = indent + 1)
    else
        print(INDENT^indent)
        print(x)
        println()
    end
end

### ---------------------------------

md = Markdown.parse("""
    # Header

    Hello World _hehe foo bar **asd**_!!

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

    """)

md2 = Markdown2.convert(md)

printmd2(md2)
