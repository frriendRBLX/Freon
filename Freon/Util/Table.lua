local TableUtil = {}

function TableUtil:Compare(A: {any}, B: {any}): boolean
    local Identical = true

    --> 1 Dimentional Table Search
    for AKey, AValue in pairs(A) do
        if AValue ~= B[AKey] then
            Identical = false
        end
    end

    return Identical
end

function TableUtil:IsEmpty(Table: {any})
    local Count = 0

    for _, _ in pairs(Table) do
        Count += 1
    end

    return (Count > 0) and true or false
end


return TableUtil