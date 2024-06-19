import regex
from langchain_core.documents import Document


class EntityFinder:
    def close_doc(self, query):
        return Document(page_content=query)

    def __call__(self, query):
        return self.close_doc(query).page_content


class RegexFinder(EntityFinder):
    def __init__(self):
        self.regex_expression = (
            r"(?P<apellido_paterno>(?:Apellido paterno|primerApellido|apellidop|apepat|paterno|apellido padre|a. paterno|apellido pat|apellido paterno|apPaterno){0<=e<=2})|"
            r"(?P<apellido_materno>(?:Apellido materno|segundoApellido|apellidom|apemat|materno|apellido madre|a. materno|apellido mat|apellido materno|apMaterno){0<=e<=2})|"
            r"(?P<dia_de_nacimiento>(?:diaNacimiento|dia nacimiento|dia_de_nacimiento){0<=e<=2})|"
            r"(?P<mes_de_nacimiento>(?:mesNacimiento|mes de nacimiento|mes_de_nacimiento){0<=e<=2})|"
            r"(?P<birth_year>(?:anoNacimiento|ano de nacimiento|ano_de_nacimiento|anoNacimiento){0<=e<=2})|"
            r"(?P<fecha_de_nacimiento>(?:fecha de nacimiento|fechadenac|fecnac|nacimiento|f. de nacimiento|fecha nacim|fecnacimiento|fec. nacim|fecha nac.|fecha nacimiento){0<=e<=2})|"
            r"(?P<estado_de_nacimiento>(?:estado de nacimiento|estnac|edonac|estadodenac|nacido en|estado nacim|e. de nacimiento|edonacimiento|estado nac.|estado nacimiento){0<=e<=2})|"
            r"(?P<entidad_federativa>(?:entidadFederativa|entidad fed|entidad federal|estado|estado de la república|entidad){0<=e<=2})|"
            r"(?P<nombre>(?:nombre|nom|nombre completo|nombres|nomb|nomb. completo|primer nombre|nombre de pila|nombres completos|nombre y apellidos|nom completo|nom. completo){0<=e<=2})|"
            r"(?P<id_cif>(?:IDCIF|ID CIF|Identificación CIF|Identificación Fiscal|Cédula de Identificación Fiscal|CIF){0<=e<=2})|"
            r"(?P<sexo>(?:sexo|género|genero|sex|género/sexo|género/sex|sexo/género|sexo/genero|sex/género|sex/genero|género sexual|sexo biologico|identidad de género|identidad de sexo){0<=e<=2})|"
            r"(?P<curp>(?:curp|clave unica de registro de poblacion){0<=e<=2})|"
            r"(?P<email>(?:email|correo electrónico|correo|e-mail){0<=e<=2})|"
            r"(?P<nss>(?:nss|numero de seguro social|número de seguro social|num de seguro social){0<=e<=2})|"
            r"(?P<codigo_postal>(?:código postal|código|c.p.|CP|cod. postal|código postal mexicano|postal code|zip code){0<=e<=2})|"
            r"(?P<null>(?:hombre|mujer|masculino|femenino|m.|f.|masc.|fem.|muj.|hom.|varón|dama|caballero){0<=e<=2})|"
            r"(?P<rfc>(?:RFC|Registro Federal de Contribuyentes){0<=e<=1})|"
            r"(?P<saldo_sar_total>(?:saldoSARTotal|saldo total SAR|total SAR|SAR total|saldo SAR|Sistema de Ahorro para el Retiro total|total Sistema de Ahorro para el Retiro|Ahorro para el Retiro total){0<=e<=2})"
        )
        self.pattern = regex.compile(
            self.regex_expression, flags=regex.IGNORECASE | regex.BESTMATCH
        )

    def close_doc(self, query):
        match = self.pattern.search(query)
        if match is None:
            return Document(page_content=query)
        if match.lastgroup == "null":
            return Document(page_content=query)
        return Document(page_content=match.lastgroup)
