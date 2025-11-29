using Arrow

function _repr(x::Arrow.ArrowVector)
    elements = [repr(x[i]) for i in 1:min(3, length(x))]
    s = join(elements, ", ")
    if length(x) > 3
        s *= ", ..."
    end
    return "[$s]"
end

function _repr(x::Tuple)
    s = join([_repr(v) for v in x], ", ")
    return "($s)"
end

function _repr(x::T) where T
    if isstructtype(T) && !isprimitivetype(T) && T != String
        fields = fieldnames(T)
        s = join(["$(f)=$(_repr(getfield(x, f)))" for f in fields], ", ")
        return "$(nameof(T))($s)"
    else
        return repr(x)
    end
end