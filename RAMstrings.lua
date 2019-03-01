do
   local sc=0
   local bc=0
   local a=debug.getstrings'RAM'
   for i=1, #a do
      a[i] = ('%q'):format(a[i])
      sc = sc + 1
      bc = bc + #a[i]
   end
   print('local preload='..table.concat(a,','))
   print("#strings, #bytes:", sc, bc)
end
