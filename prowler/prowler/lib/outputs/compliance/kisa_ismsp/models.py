from typing import Optional

from pydantic.v1 import BaseModel, validator


class AWSKISAISMSPModel(BaseModel):
    """
    The AWS KISA-ISMS-P Model outputs findings in a format compliant with the AWS KISA-ISMS-P standard
    """

    Provider: str
    Description: str
    AccountId: str
    Region: str
    AssessmentDate: str
    Requirements_Id: str
    Requirements_Name: str
    Requirements_Description: str
    Requirements_Attributes_Domain: str
    Requirements_Attributes_Subdomain: str
    Requirements_Attributes_Section: str
    Requirements_Attributes_Purpose: Optional[list[str]] = None
    Requirements_Attributes_ActionPlan: Optional[list[str]] = None
    Requirements_Attributes_AuditChecklist: Optional[list[str]] = None
    Requirements_Attributes_RelatedRegulations: Optional[list[str]] = None
    Requirements_Attributes_AuditEvidence: Optional[list[str]] = None
    Requirements_Attributes_NonComplianceCases: Optional[list[str]] = None
    Status: str
    StatusExtended: str
    ResourceId: str
    ResourceName: str
    CheckId: str
    Muted: bool

    @validator(
        "Requirements_Attributes_Purpose",
        "Requirements_Attributes_ActionPlan",
        pre=True,
    )
    def _ensure_list(cls, value):
        if value is None or isinstance(value, list):
            return value
        return [value]