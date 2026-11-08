export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      audit_log: {
        Row: {
          action: string
          actor: string | null
          at: string
          client_info: Json
          id: number
          new_data: Json | null
          old_data: Json | null
          row_id: string
          table_name: string
        }
        Insert: {
          action: string
          actor?: string | null
          at?: string
          client_info?: Json
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          row_id: string
          table_name: string
        }
        Update: {
          action?: string
          actor?: string | null
          at?: string
          client_info?: Json
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          row_id?: string
          table_name?: string
        }
        Relationships: []
      }
      cost_centers: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          updated_at: string
          usali_department: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          updated_at?: string
          usali_department?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          updated_at?: string
          usali_department?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cost_centers_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      legal_entities: {
        Row: {
          accounting_regime: string
          code: string
          costing_method: string
          created_at: string
          created_by: string | null
          external_codes: Json
          id: string
          name: string
          org_id: string
          tax_code: string | null
          updated_at: string
        }
        Insert: {
          accounting_regime?: string
          code: string
          costing_method?: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          id?: string
          name: string
          org_id: string
          tax_code?: string | null
          updated_at?: string
        }
        Update: {
          accounting_regime?: string
          code?: string
          costing_method?: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          id?: string
          name?: string
          org_id?: string
          tax_code?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "legal_entities_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      outlet_types: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "outlet_types_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      outlets: {
        Row: {
          code: string
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          id: string
          name: string
          outlet_type_id: string
          property_id: string
          updated_at: string
        }
        Insert: {
          code: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          outlet_type_id: string
          property_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          outlet_type_id?: string
          property_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "outlets_cost_center_id_fkey"
            columns: ["cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outlets_outlet_type_id_fkey"
            columns: ["outlet_type_id"]
            isOneToOne: false
            referencedRelation: "outlet_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outlets_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          code: string
          created_at: string
          description_vi: string
          module: string
          name_vi: string
          risk_level: string
          sort_order: number
        }
        Insert: {
          code: string
          created_at?: string
          description_vi: string
          module: string
          name_vi: string
          risk_level: string
          sort_order: number
        }
        Update: {
          code?: string
          created_at?: string
          description_vi?: string
          module?: string
          name_vi?: string
          risk_level?: string
          sort_order?: number
        }
        Relationships: []
      }
      profiles: {
        Row: {
          active: boolean
          created_at: string
          employee_code: string | null
          full_name: string
          id: string
          phone: string | null
          pin_hash: string | null
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          employee_code?: string | null
          full_name?: string
          id: string
          phone?: string | null
          pin_hash?: string | null
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          employee_code?: string | null
          full_name?: string
          id?: string
          phone?: string | null
          pin_hash?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      properties: {
        Row: {
          address: string | null
          code: string
          created_at: string
          created_by: string | null
          id: string
          legal_entity_id: string
          name: string
          org_id: string
          rooms_count: number
          sod_profile: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id: string
          name: string
          org_id: string
          rooms_count?: number
          sod_profile?: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id?: string
          name?: string
          org_id?: string
          rooms_count?: number
          sod_profile?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "properties_legal_entity_id_org_id_fkey"
            columns: ["legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "properties_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          created_at: string
          created_by: string | null
          permission_code: string
          role_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          permission_code: string
          role_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          permission_code?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_code_fkey"
            columns: ["permission_code"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          active: boolean
          code: string
          copied_from_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          is_system: boolean
          name_vi: string
          org_id: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          code: string
          copied_from_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_system?: boolean
          name_vi: string
          org_id: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          code?: string
          copied_from_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_system?: boolean
          name_vi?: string
          org_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "roles_copied_from_id_fkey"
            columns: ["copied_from_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "roles_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      room_types: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          max_guests: number | null
          name: string
          property_id: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          max_guests?: number | null
          name: string
          property_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          max_guests?: number | null
          name?: string
          property_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_types_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      rooms: {
        Row: {
          created_at: string
          created_by: string | null
          floor: string | null
          id: string
          property_id: string
          room_no: string
          room_type_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          floor?: string | null
          id?: string
          property_id: string
          room_no: string
          room_type_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          floor?: string | null
          id?: string
          property_id?: string
          room_no?: string
          room_type_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rooms_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rooms_room_type_id_property_id_fkey"
            columns: ["room_type_id", "property_id"]
            isOneToOne: false
            referencedRelation: "room_types"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      sod_exceptions: {
        Row: {
          approved_by: string
          created_at: string
          created_by: string | null
          id: string
          property_id: string
          reason: string
          rule_code: string
          updated_at: string
          user_id: string
          valid_to: string
        }
        Insert: {
          approved_by: string
          created_at?: string
          created_by?: string | null
          id?: string
          property_id: string
          reason: string
          rule_code: string
          updated_at?: string
          user_id: string
          valid_to: string
        }
        Update: {
          approved_by?: string
          created_at?: string
          created_by?: string | null
          id?: string
          property_id?: string
          reason?: string
          rule_code?: string
          updated_at?: string
          user_id?: string
          valid_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "sod_exceptions_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      user_permission_overrides: {
        Row: {
          created_at: string
          effect: string
          granted_by: string | null
          id: string
          permission_code: string
          property_id: string | null
          reason: string
          updated_at: string
          user_id: string
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          created_at?: string
          effect: string
          granted_by?: string | null
          id?: string
          permission_code: string
          property_id?: string | null
          reason: string
          updated_at?: string
          user_id: string
          valid_from?: string
          valid_to?: string | null
        }
        Update: {
          created_at?: string
          effect?: string
          granted_by?: string | null
          id?: string
          permission_code?: string
          property_id?: string | null
          reason?: string
          updated_at?: string
          user_id?: string
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_permission_overrides_permission_code_fkey"
            columns: ["permission_code"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "user_permission_overrides_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      user_property_roles: {
        Row: {
          created_at: string
          granted_by: string | null
          id: string
          outlet_ids: string[] | null
          property_id: string | null
          role_id: string
          updated_at: string
          user_id: string
          valid_from: string
          valid_to: string | null
          warehouse_ids: string[] | null
        }
        Insert: {
          created_at?: string
          granted_by?: string | null
          id?: string
          outlet_ids?: string[] | null
          property_id?: string | null
          role_id: string
          updated_at?: string
          user_id: string
          valid_from?: string
          valid_to?: string | null
          warehouse_ids?: string[] | null
        }
        Update: {
          created_at?: string
          granted_by?: string | null
          id?: string
          outlet_ids?: string[] | null
          property_id?: string | null
          role_id?: string
          updated_at?: string
          user_id?: string
          valid_from?: string
          valid_to?: string | null
          warehouse_ids?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "user_property_roles_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_property_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      warehouses: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          kind: string
          name: string
          outlet_id: string | null
          property_id: string
          room_id: string | null
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          kind: string
          name: string
          outlet_id?: string | null
          property_id: string
          room_id?: string | null
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          kind?: string
          name?: string
          outlet_id?: string | null
          property_id?: string
          room_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "warehouses_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warehouses_outlet_id_property_id_fkey"
            columns: ["outlet_id", "property_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "warehouses_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warehouses_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warehouses_room_id_property_id_fkey"
            columns: ["room_id", "property_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      bootstrap_initial_org: {
        Args: {
          p_admin_one: string
          p_admin_two: string
          p_legal_entity_code: string
          p_legal_entity_name: string
          p_org_name: string
          p_property_code: string
          p_property_name: string
          p_test_user: string
        }
        Returns: Json
      }
      has_perm: {
        Args: { p_perm: string; p_property: string; p_warehouse?: string }
        Returns: boolean
      }
      my_permissions: { Args: { p_property: string }; Returns: string[] }
      my_property_ids: { Args: never; Returns: string[] }
      my_warehouse_ids: { Args: { p_property: string }; Returns: string[] }
      norm_text: { Args: { p_text: string }; Returns: string }
      require_perm: {
        Args: { p_perm: string; p_property: string; p_warehouse?: string }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
