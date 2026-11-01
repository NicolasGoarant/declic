# Lecteur protobuf minimal (fils « wire format ») : assez pour le GTFS-RT, sans dépendance. Rend, pour un message, la
# liste [[numéro de champ, valeur]] ; les valeurs imbriquées restent des chaînes binaires, à relire avec `champs`.
module Trains
  module Protobuf
    module_function

    def champs(octets)
      i = 0
      out = []
      n = octets.bytesize
      b = octets.b
      while i < n
        cle, i = varint(b, i)
        num, type = cle >> 3, cle & 7
        case type
        when 0 then valeur, i = varint(b, i)
        when 1 then valeur = b.byteslice(i, 8); i += 8
        when 2
          long, i = varint(b, i)
          valeur = b.byteslice(i, long); i += long
        when 5 then valeur = b.byteslice(i, 4); i += 4
        else raise ArgumentError, "type protobuf inconnu : #{type}"
        end
        raise ArgumentError, "message protobuf tronqué" if i > n

        out << [num, valeur]
      end
      out
    end

    def varint(b, i)
      r = 0
      decalage = 0
      loop do
        octet = b.getbyte(i) or raise ArgumentError, "varint tronqué"
        i += 1
        r |= (octet & 0x7f) << decalage
        return [r, i] if octet < 0x80

        decalage += 7
        raise ArgumentError, "varint trop long" if decalage > 63
      end
    end

    # varint interprété comme entier signé sur 64 bits (le retard peut être négatif)
    def signe(v)
      v >= (1 << 63) ? v - (1 << 64) : v
    end
  end
end
